# frozen_string_literal: true

require_relative 'enum_machine/version'
require_relative 'enum_machine/driver_simple_class'
require_relative 'enum_machine/build_attribute'
require_relative 'enum_machine/build_class'
require_relative 'enum_machine/machine'
require 'active_support'

module EnumMachine

  class Error < StandardError; end

  def self.[](args)
    DriverSimpleClass.call(args)
  end

end

ActiveSupport.on_load(:active_record) do
  require_relative 'enum_machine/driver_active_record'
  ActiveRecord::Base.extend(EnumMachine::DriverActiveRecord)
end
