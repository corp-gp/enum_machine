# frozen_string_literal: true

require_relative "enum_machine/version"
require_relative "enum_machine/driver_simple_class"
require_relative "enum_machine/build_attribute"
require_relative "enum_machine/attribute_persistence_methods"
require_relative "enum_machine/build_class"
require_relative "enum_machine/machine"
require "active_support"

module EnumMachine
  class Error < StandardError; end

  class InvalidTransition < Error
    attr_reader :from, :to, :enum_const

    def initialize(machine, from, to)
      @from = from
      @to = to
      @enum_const =
        begin
          machine.base_klass.const_get(machine.enum_const_name)
        rescue NameError # rubocop:disable Lint/SuppressedException
        end
      super("Transition #{from.inspect} => #{to.inspect} not defined in enum_machine :#{machine.attr_name}")
    end
  end

  def self.[](args)
    DriverSimpleClass.call(args)
  end
end

ActiveSupport.on_load(:active_record) do
  require_relative "enum_machine/driver_active_record"
  ActiveSupport.on_load(:active_record) { extend EnumMachine::DriverActiveRecord }
end
