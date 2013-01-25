spec = Gem::Specification.new do |s|
  s.name = 'em-postgres'
  s.version = '0.1.0'
  s.date = '2013-01-25'
  s.summary = 'Async PostgreSQL client API for Ruby/EventMachine'
  s.email = "ceo@prepor.ru"
  s.homepage = "http://github.com/prepor/em-postgres"
  s.description = 'Async PostgreSQL client API for Ruby/EventMachine'
  s.has_rdoc = false
  s.authors = ["Andrew Rudenko"]
  s.add_dependency('eventmachine', '>= 0.12')
  s.add_dependency('pg', '>= 0.14')

  # git ls-files
  s.files = %w[
    README
    Rakefile
    em-postgres.gemspec
    lib/em-postgres/postgres.rb
    lib/em-postgres/connection.rb
    lib/em-postgres.rb
    spec/helper.rb
    spec/postgres_spec.rb
  ]
end
  # = MANIFEST =
  s.files = %w[

  ]
  # = MANIFEST =
