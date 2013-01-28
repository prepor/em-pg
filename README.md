EM::PG
======

One more EventMachine wrapper for Postgresql [pg-lib](https://github.com/ged/ruby-pg).

Features
--------

* Fully async including connect and right usage of #busy and #consume_input;
* All results are standard deferrable objects;
* Distinct exceptions hierarchy;
* Wrapper for [Green](https://github.com/prepor/green) and adapter fot [Sequel](http://sequel.rubyforge.org/).

Usage
-----

```ruby
gem "em-pg"
```

```ruby
require "em/pg"

EM.run do
  db = EM::PG.new host: "localhost", port: 5432, dbname: "test", user: "postgres", password: "postgres"
  db.callback do
    q = db.send_query "select 1"
	q.callback do |res|
	  puts "RESULT: #{res.inspect}"
	  EM.stop
	end
	q.errback do |e|
	  raise e
	end
  end
  
  db.errback do |e|
    raise e
  end
end
```

To all errbacks pass one argument, instance of EM::PG::Error. So it easy to write common handlers and wrappers for something like EM-Synchrony and Green.

### Supported methods

* `send_query`
* `send_prepare`
* `send_query_prepared`
* `send_describe_prepared`
* `send_describe_portal`

All have same semantics as in pg-lib, but result is a Deferrable object

### Disconnects

On disconnect all current queries will be failed with exception DisconnectError. You also can pass :on_disconnect callback with options, wich will be called before queries errbacks.

EM::PG doesn't have reconnect strategy, you should handle disconnects by youself.

### Logging

You can pass :logger option or set `EM::PG.logger` for all instances.

Exceptions
----------

```
 EM::PG::Error
   ConnectionRefusedError
   DisconnectError
   BadStateError
   UnexpectedStateError
     BadConnectionStatusError
	 BadPollStatusError
   PGError
```

* ConnectionRefusedError - can't connect. Have field `.message` with reason;
* DisconnectError - connection disconnected. Will be raised on all uncompleted queries;
* BadStateError - you try do something while a wrong state. For example send query on not connected client;
* UnexpectedStateError - something gone wrong :(
* PGError - original PG exceptions was raised. Have field `.original`.

See also
--------

* [em-pg-client](https://github.com/royaltm/ruby-em-pg-client) - good wrapper around pg-lib with reconnects.
* [em-postgres](https://github.com/jtoy/em-postgres)
* [em-postgresql-sequel](https://github.com/jzimmek/em-postgresql-sequel)

