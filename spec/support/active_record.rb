# frozen_string_literal: true

require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
  create_table(:test_models, force: true) do |t|
    t.string :state
    t.string :color
    t.text :message
    t.text :params
  end
end
