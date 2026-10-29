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
            enum_values     = params.fetch(:enum)
            i18n_scope      = params.fetch(:i18n_scope, nil)
            value_decorator = params.fetch(:value_decorator, nil)

            if defined?(ActiveRecord) && klass <= ActiveRecord::Base
              klass.enum_machine(attr, enum_values, i18n_scope: i18n_scope)
            else
              enum_class = EnumMachine.enum(enum_values, i18n_scope: i18n_scope, value_decorator: value_decorator)
              enum_decorator = BuildEnumClass.build_enum_decorator(enum_class, attr)
              enum_class.define_singleton_method(:enum_decorator) { enum_decorator }

              klass.include(enum_decorator)
              enum_decorator
            end
          end
        end
      end
    end
  end
end
