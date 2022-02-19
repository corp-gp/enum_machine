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

            attribute_klass =
              BuildAttribute.call(
                attr:        attr,
                read_method: read_method,
                enum_values: enum_values,
                i18n_scope:  i18n_scope,
              )

            klass.class_variable_set("@@#{attr}_attribute", attribute_klass)

            klass.alias_method read_method, attr
            klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
              # def state
              #   @state_enum ||= @@state_attribute.new(self)
              # end

              def #{attr}
                @#{attr}_enum ||= @@#{attr}_attribute.new(self)
              end
            RUBY

            next unless enum_class

            klass.const_set attr_klass_name, BuildClass.new(enum_values)
          end
        end
      end
    end

  end
end
