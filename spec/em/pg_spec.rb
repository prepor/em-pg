require "spec_helper"
describe EM::PG do
  let(:db_options) do
    {}
  end
  let(:db) do
    EM::PG.new(DB_CONFIG.merge(db_options)).tap { |o| sync o }
  end

  include Minitest::EMSync

  it "should invoke errback on connection failure" do
    conn = EM::PG.new(DB_CONFIG.merge user: "unexist")
    proc { sync conn }.must_raise EM::PG::ConnectionRefusedError
  end

  describe "with on_disconnect" do
    let(:m) { EM::DefaultDeferrable.new }

    let(:db_options) do
      { on_disconnect: proc { m.succeed } }
    end

    it "should invoke on_disconnect" do
      db
      EM.next_tick { db.unbind } # don't known how to emulate real disconnect
      sync m
    end
  end

  it "should fail current queries on disconnect" do
    q1 = db.send_query("select pg_sleep(10);")
    q2 = db.send_query("select pg_sleep(10);")
    EM.next_tick { db.unbind }
    proc { sync q1 }.must_raise EM::PG::DisconnectError
    proc { sync q2 }.must_raise EM::PG::DisconnectError
  end

  describe "successful connection" do
    after do
      db.close
    end

    it "should create a new connection" do
      db.state.must_equal :connected
    end

    it "should execute sql" do
      query = db.send_query("select 1;")
      res = sync query
      res.first["?column?"].must_equal "1"
    end

    it "allow custom error callbacks for each query" do
      query = db.send_query("select 1 from")
      proc { sync query }.must_raise EM::PG::PGError
    end

    it "queue up large amount of queries and execute them in order" do
      results = []
      m = EM::DefaultDeferrable.new
      100.times do |i|
        db.send_query("select #{i} AS x;").callback do |res|
          results << res.first["x"].to_i
          if results.size == 100
            results.reduce(0, &:+).must_equal 100.times.reduce(0, &:+)
            m.succeed
          end
        end
      end
      sync m
    end

    describe "not yet connected" do
      let(:db) { EM::PG.new DB_CONFIG }
      it "should fail query" do
        q1 = db.send_query("select 1;")
        proc { sync q1 }.must_raise EM::PG::BadStateError
      end
    end
  end

end
