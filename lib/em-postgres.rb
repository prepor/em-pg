require 'eventmachine'
require 'pg'
require 'logger'

module EM
  class Postgres
    VERSION = '0.1.0'
    include EM::Deferrable

    class Error < RuntimeError
      def initialize(params = {})
        params.each { |k, v| self.send("#{k}=", v) }
      end
    end
    class ConnectionRefusedError < Error
      attr_accessor :message
    end
    class DisconnectError < Error; end
    class BadStateError < Error
      attr_accessor :state
    end
    class UnexpectedStateError < Error; end
    class BadConnectionStatusError < UnexpectedStateError; end
    class BadPollStatsError < UnexpectedStateError; end
    class PGError < Error
      attr_accessor :original
    end

    class Watcher < EM::Connection
      attr_accessor :postgres
      def initialize(postgres)
        @postgres = postgres
      end

      def notify_readable
        @postgres.handle
      end

      def notify_writable
        self.notify_writable = false
        @postgres.handle
      end

      def unbind
        @postgres.unbind
      end

    end


    class Query
      include EM::Deferrable
      attr_accessor :method, :args
      def initialize(method, args)
        @method, @args = method, args
      end
    end

    attr_accessor :pg, :conn, :opts, :state, :logger, :watcher, :on_disconnect
    def initialize(opts)
      opts = opts.dup
      @logger = opts.delete(:logger) || Logger.new(STDOUT)
      @on_disconnect = opts.delete(:on_disconnect)
      @opts = opts
      @state = :connecting

      @pg = PG::Connection.connect_start(@opts)
      @queue = []

      @watcher = EM.watch(@pg.socket, Watcher, self)
      @watcher.notify_readable = true
      check_connect
    end

    def handle
      case @state
      when :connecting
        check_connect
      when :waiting
        get_result do |res|
          result_for_query res
        end
      else # try check result, may be it close-message
        get_result do |res|
          if res.is_a? Exception
            unbind res
          else
            error "Result in unexpected state #{@state}: #{res.inspect}"
          end
        end
      end
    end

    def check_connect
      status = @pg.connect_poll
      case status
      when PG::PGRES_POLLING_OK
        if pg.status == PG::CONNECTION_OK
          connected
        elsif pg.status == PG::CONNECTION_BAD
          connection_refused
        else
          raise BadConnectionStatusError.new
        end
      when PG::PGRES_POLLING_READING
      when PG::PGRES_POLLING_WRITING
        @watcher.notify_writable = true
      when PG::PGRES_POLLING_FAILED
        @watcher.detach
        connection_refused
      else
        raise BadPollStatsError.new
      end
    end

    [:send_query, :send_query_prepared, :send_describe_prepared, :send_describe_portal].each do |m|
      define_method(m) do |*args|
        async_exec(m, *args)
      end
    end

    def async_exec(m, *args)
      q = Query.new m, args
      case @state
      when :waiting
        add_to_queue q
      when :connected
        run_query! q
      else
        q.fail BadStateError.new(state: @state)
      end
      q
    end

    def add_to_queue(query)
      @queue << query
    end

    def run_query!(q)
      @current_query = q
      @state = :waiting
      debug(["EM::Postgres", q.method, q.args])
      @pg.send(q.method, *q.args)
    end

    def try_next_from_queue
      q = @queue.shift
      if q
        run_query! q
      end
    end

    def get_result(&clb)
      begin
        @pg.consume_input # can raise exceptins
        if @pg.is_busy
        else
          clb.call @pg.get_last_result # can raise exceptions
        end
      rescue PG::Error => e
        clb.call PGError.new(original: e)
      end
    end

    def result_for_query(res)
      @state = :connected
      q = @current_query
      @current_query = nil
      if res.is_a? Exception
        q.fail res
      else
        q.succeed res
      end
      try_next_from_queue
    end

    def connected
      @state = :connected
      succeed :connected
    end

    def connection_refused
      @state = :connection_refused
      logger.error [:connection_refused, @pg.error_message]
      fail ConnectionRefusedError.new(message: @pg.error_message)
    end

    def unbind(reason = nil)
      return if @state == :disconnected
      logger.error [:disconnected, reason]
      @state = :disconnected
      @watcher.detach
      @on_disconnect.call if @on_disconnect
      fail_queries DisconnectError.new
    end

    def close
      @state = :closed
      @watcher.detach
      @pg.finish
      fail_queries :closed
    end

    def fail_queries(exc)
      @current_query.fail exc if @current_query
      @queue.each { |q| q.fail exc }
    end

    [:trace, :debug, :info, :warn, :error, :fatal].each do |m|
      define_method(m) do |*args, &blk|
        logger.send(m, *args, &blk)
      end
    end
  end
end
