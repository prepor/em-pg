require "spec_helper"
describe EM::Postgres do
  let(:db_options) do
    {}
  end
  let(:db) do
    EM::Postgres.new(DB_CONFIG.merge(db_options)).tap { |o| sync o }
  end

  include WithFiberedEM

  it "should invoke errback on connection failure" do
    conn = EM::Postgres.new(DB_CONFIG.merge user: "unexist")
    proc { sync conn }.must_raise EM::Postgres::ConnectionRefusedError
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
    q1 = db.send_query("select sleep(10);")
    q2 = db.send_query("select sleep(10);")
    EM.next_tick { db.unbind }
    proc { sync q1 }.must_raise EM::Postgres::DisconnectError
    proc { sync q2 }.must_raise EM::Postgres::DisconnectError
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
      proc { sync query }.must_raise EM::Postgres::PGError
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
      let(:db) { EM::Postgres.new DB_CONFIG }
      it "should fail query" do
        q1 = db.send_query("select 1;")
        proc { sync q1 }.must_raise EM::Postgres::BadStateError
      end
    end
  end


  # it "should execute sql" do
  #   EventMachine.run {
  #     #EM.add_periodic_timer(1){ puts }
  #     conn = EventMachine::Postgres.new(:database => "test")
  #     query = conn.execute("select 1;")

  #     query.callback{ |res|
  #       res.first["?column?"].should == "1"
  #       EventMachine.stop
  #     }
  #   }
  # end

  # it "should accept block as query callback" do
  #   EventMachine.run {
  #     conn = EventMachine::Postgres.new(:database => 'test')
  #     conn.execute("select 1;") { |res|
  #       res.first["?column?"].should == "1"
  #       EventMachine.stop
  #     }
  #   }
  # end

  # it "should accept paramaters" do
  #   EventMachine.run {
  #     conn = EventMachine::Postgres.new(:database => 'test')
  #     conn.execute("select $1::int AS first,$2::int AS second,$3::varchar AS third;",[1,nil,'']) { |res|
  #       res.first["first"].should == "1"
  #       res.first["second"].should == nil
  #       res.first["third"].should == ""
  #       EventMachine.stop
  #     }
  #   }
  # end

  # it "allow custom error callbacks for each query" do
  #   EventMachine.run {
  #     conn = EventMachine::Postgres.new(:database => "test")
  #     query = conn.execute("select 1 from")
  #     query.errback { |res|
  #       #res.class.should == Mysql::Error
  #       1.should == 1
  #       EventMachine.stop
  #       1.should == 2 #we should never get here
  #     }
  #   }
  # end


  # it "queue up queries and execute them in order" do
  #   EventMachine.run {
  #     conn = EventMachine::Postgres.new(:database => 'test')

  #     results = []
  #     conn.execute("select 1 AS x;") {|res| puts res.inspect; results.push(res.first["x"].to_i)}
  #     conn.execute("select 2 AS x;") {|res| puts res.inspect;results.push(res.first["x"].to_i)}
  #     conn.execute("select 3 AS x;") {|res| puts res.inspect;results.push(res.first["x"].to_i)}
  #     EventMachine.add_timer(0.05) {
  #       results.should == [1,2,3]
  #       #conn.connection_pool.first.close
  
  #       EventMachine.stop
  #     }
  #   }
  # end



  # it "should continue processing queries after hitting an error" do
  #   EventMachine.run {
  #     conn = EventMachine::Postgres.new(:database=> 'test')
  #     #errorback = Proc.new{
  #     #  true.should == true
  #       #EventMachine.stop
  #     #}
  #     q = conn.execute("select 1+ from table;") 
  #     q.errback{|r| puts "hi"; true.should == true } 
  #     conn.execute("select 1+1;"){ |res|
  #       res.first["?column?"].to_i.should == 2
  #       EventMachine.stop
  #     }
  #   }
  # end

  # it "should work with bind parameters" do
  #   EventMachine.run {
  #     conn = EventMachine::Postgres.new(:database=> 'test')
  #     conn.execute("select $1::int as bind1;",[4]){|r|
  #       r.first["bind1"].to_i.should == 4
  #     }
  #     conn.execute("select $1::text as bind1;",['four']){|r|
  #       r.first["bind1"].should == 'four'
  #       EventMachine.stop
  #     }
  
  #   }
  # end
  
  # it "should allow the creation of a prepare statement" do
  #   EventMachine.run {
  #     conn = EventMachine::Postgres.new(:database=> 'test')
  #     prepare_name = "random#{rand(69)}"
  #     i = rand(69)
  #     conn.prepare(prepare_name,"select #{i};")
  #     conn.execute(prepare_name){|r|
  #       r.first["?column?"].to_i.should == i
  #       EventMachine.stop
  #     }      
  #   }
  # end
  
  

  #  it "should reconnect when disconnected" do
  #    # to test, run:
  #    # mysqladmin5 -u root kill `mysqladmin -u root processlist | grep "select sleep(5)" | cut -d'|' -f2`
  #
  #    EventMachine.run {
  #      conn = EventMachine::MySQL.new(:host => 'localhost')
  #
  #      query = conn.query("select sleep(5)")
  #      query.callback {|res|
  #        res.fetch_row.first.to_i.should == 0
  #        EventMachine.stop
  #      }
  #    }
  #  end

end
