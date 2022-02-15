# frozen_string_literal: true

require 'active_record'

RSpec.configure do |config|
  config.around(:each, :ar) do |example|
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
    ActiveRecord::Migration.verbose = false

    ActiveRecord::Schema.define do
      create_table(:test_models, force: true) do |t|
        t.string :state
        t.string :color
        t.text :message
      end
    end

    example.run

    ActiveRecord::Base.remove_connection
  end
end
