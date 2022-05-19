# frozen_string_literal: true

require 'ostruct'
Object.const_set(:Rails, OpenStruct.new(env: OpenStruct.new(test?: true))) # rubocop:disable Style/OpenStructUse

require 'enum_machine'
require 'bundler'

Bundler.require :default
require 'support/active_record'
require 'support/test_model'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
