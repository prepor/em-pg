ENV['BUNDLE_GEMFILE'] = File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup'

require 'em/pg'

require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
require 'minitest/em_sync'

logger = Logger.new nil

DB_CONFIG = {
  host: "localhost",
  port: 5432,
  dbname: "test",
  user: "postgres",
  password: "postgres",
  logger: logger
}

MiniTest::Reporters.use! MiniTest::Reporters::SpecReporter.new
