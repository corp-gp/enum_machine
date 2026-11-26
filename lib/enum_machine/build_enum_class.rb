# frozen_string_literal: true

module EnumMachine
  module BuildEnumClass
    def self.call(enum_values:, i18n_scope:, value_class:, machine: nil)
      aliases = machine&.instance_variable_get(:@aliases) || {}

      Class.new do
        const_set(:VALUE_CLASS, value_class)

        define_singleton_method(:machine) { machine } if machine
        define_singleton_method(:values) { enum_values.map { value_class.new(_1).freeze } }

        value_attribute_mapping = values.to_h { [_1.to_s, _1] }
        define_singleton_method(:value_attribute_mapping) { value_attribute_mapping }
        define_singleton_method(:[]) do |enum_value|
          key = enum_value.to_s
          # Check for key existence because `[]` will call `default_proc`, and we don’t want that
          value_attribute_mapping[key] if value_attribute_mapping.key?(key)
        end

        define_singleton_method(:enum_decorator) do
          @enum_decorator ||= BuildEnumClass.build_enum_decorator(self, Inflector.underscore(Inflector.demodulize(name)))
        end

        if i18n_scope
          def self.values_for_form(specific_values = nil)
            (specific_values || values).map { |v| [human_name_for(v), v] }
          end

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def self.human_name_for(name)
            #   ::I18n.t(name, scope: "enums.test_model", default: name)
            # end

            def self.human_name_for(name)
              ::I18n.t(name, scope: "enums.#{i18n_scope}", default: name)
            end
          RUBY
        end

        enum_values.each do |enum_value|
          const_set Inflector.underscore(enum_value).upcase, value_class.new(enum_value).freeze
        end

        aliases.each_key do |key|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def self.forming
            #   @alias_forming ||= machine.fetch_alias('forming').freeze
            # end

            def self.#{key}
              @alias_#{key} ||= machine.fetch_alias('#{key}').freeze
            end
          RUBY
        end

        private_class_method def self.const_missing(name)
          name_s = name.to_s
          return super unless name_s.include?("__")

          const_set name_s, name_s.split("__").map { |i| const_get(i) }.freeze
        end
      end
    end

    def self.build_enum_decorator(enum_class, attr)
      enum_const_name = attr.to_s.upcase

      define_methods =
        Module.new do
          define_method(attr) do
            enum_value = super()
            return unless enum_value

            enum_class.value_attribute_mapping.fetch(enum_value)
          end
        end

      Module.new do
        define_singleton_method(:included) do |decorating_class|
          decorating_class.prepend define_methods
          decorating_class.const_set enum_const_name, enum_class
        end
      end
    end
  end
end
