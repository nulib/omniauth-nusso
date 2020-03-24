# frozen_string_literal: true

require 'bundler/setup'
require 'simplecov'
require 'coveralls'
require 'rack/test'
require 'webmock/rspec'
require 'omniauth'

Coveralls.wear!

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
  [
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ]
)

SimpleCov.start do
  add_filter 'spec'
  add_filter 'vendor'
end

require 'omniauth/nusso'

OmniAuth.configure do |config|
  config.logger = Logger.new(IO::NULL)
end

RSpec.configure do |config|
  config.include WebMock::API
  config.include Rack::Test::Methods
  config.extend OmniAuth::Test::StrategyMacros, type: :strategy

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
