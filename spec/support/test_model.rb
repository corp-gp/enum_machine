# frozen_string_literal: true

require 'active_record'

class TestModel < ActiveRecord::Base

  def self.model_name
    ActiveModel::Name.new(self, nil, 'test_model')
  end

end
