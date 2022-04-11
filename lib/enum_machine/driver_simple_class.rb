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
            enum_class   = params.fetch(:enum_class, true)

            attr_klass_name = attr.to_s.capitalize
            read_method = "__#{attr}"

            attribute_klass_mapping =
              enum_values.to_h do |enum_value|
                [
                  enum_value,
                  BuildAttribute.call(enum_values: enum_values, i18n_scope: i18n_scope).new(enum_value),
                ]
              end
            klass.class_variable_set("@@#{attr}_attribute_mapping", attribute_klass_mapping.freeze)

            klass.alias_method read_method, attr
            klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
              # def state
              #   @@state_attribute_mapping.fetch(__state)
              # end

              def #{attr}
                @@#{attr}_attribute_mapping.fetch(#{read_method})
              end
            RUBY

            next unless enum_class

            klass.const_set attr_klass_name, BuildClass.new(enum_values, i18n_scope: i18n_scope)
          end
        end
      end
    end

  end
end
