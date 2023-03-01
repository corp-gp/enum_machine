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

            if defined?(ActiveRecord) && klass <= ActiveRecord::Base
              klass.enum_machine(attr, enum_values, i18n_scope: i18n_scope)
            else
              enum_const_name = attr.to_s.upcase
              enum_klass = BuildClass.call(enum_values: enum_values, i18n_scope: i18n_scope)

              enum_value_klass = BuildAttribute.call(enum_values: enum_values, i18n_scope: i18n_scope)
              enum_klass.const_set :VALUE_KLASS, enum_value_klass

              value_attribute_mapping = enum_values.to_h { |enum_value| [enum_value, enum_klass::VALUE_KLASS.new(enum_value).freeze] }

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
              enum_klass.define_singleton_method(:decorator) { enum_decorator }

              klass.include(enum_decorator)
              enum_decorator
            end
          end
        end
      end
    end

  end
end
