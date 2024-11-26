# frozen_string_literal: true

module EnumMachine
  module DriverSimpleClass

    # include EnumMachine[
    #   state: { enum: %w[choice in_delivery], i18n_scope: 'line_item.state' },
    #   color: { enum: %w[red green yellow] },
    #   type:  { enum: %w[CartType BookmarkType] },
    # ]
    def self.call(args)
      Module.new do
        define_singleton_method(:included) do |klass|
          args.each do |attr, params|
            enum_values  = params.fetch(:enum)
            i18n_scope   = params.fetch(:i18n_scope, nil)
            value_class  = params.fetch(:value_class, Class.new(String))

            if defined?(ActiveRecord) && klass <= ActiveRecord::Base
              klass.enum_machine(attr, enum_values, i18n_scope: i18n_scope)
            else
              enum_const_name = attr.to_s.upcase
              enum_klass = BuildClass.call(enum_values: enum_values, i18n_scope: i18n_scope)

              enum_attribute_module = BuildAttribute.call(enum_values: enum_values, i18n_scope: i18n_scope)

              value_class.include(enum_attribute_module)
              enum_klass.const_set(:VALUE_CLASS, value_class)

              value_attribute_mapping =
                enum_values.to_h do |enum_value|
                  value = enum_values.detect { enum_value == _1 } || enum_value
                  value = enum_klass::VALUE_CLASS.new(value) unless value.is_a?(enum_klass::VALUE_CLASS)
                  [enum_value, value.freeze]
                end

              define_methods =
                Module.new do
                  define_method(attr) do
                    enum_value = super()
                    return unless enum_value

                    value_attribute_mapping.fetch(enum_value)
                  end
                end

              enum_decorator =
                Module.new do
                  define_singleton_method(:included) do |decorating_klass|
                    decorating_klass.prepend define_methods
                    decorating_klass.const_set enum_const_name, enum_klass
                  end
                end
              enum_klass.define_singleton_method(:decorator_module) { enum_decorator }

              klass.include(enum_decorator)
              enum_decorator
            end
          end
        end
      end
    end

  end
end
