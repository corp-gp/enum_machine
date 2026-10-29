# frozen_string_literal: true

require_relative "enum_machine/version"
require_relative "enum_machine/driver_simple_class"
require_relative "enum_machine/build_value_class"
require_relative "enum_machine/attribute_persistence_methods"
require_relative "enum_machine/build_enum_class"
require_relative "enum_machine/machine"
require "active_support"
require "active_support/core_ext/string"

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

  # Enum class without a host class: constants, `values`, `[]`, predicates and decorator
  #
  #   COLOR = EnumMachine.enum(%w[red green], i18n_scope: "product.color", value_decorator: ColorDecorator)
  #   COLOR::RED.red? # => true
  def self.enum(enum_values, i18n_scope: nil, value_decorator: nil)
    value_class = BuildValueClass.call(enum_values: enum_values, i18n_scope: i18n_scope, value_decorator: value_decorator)
    BuildEnumClass.call(enum_values: enum_values, i18n_scope: i18n_scope, value_class: value_class)
  end
end

ActiveSupport.on_load(:active_record) do
  require_relative "enum_machine/driver_active_record"
  ActiveSupport.on_load(:active_record) { extend EnumMachine::DriverActiveRecord }
end
