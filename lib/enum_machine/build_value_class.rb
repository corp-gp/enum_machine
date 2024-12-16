# frozen_string_literal: true

module EnumMachine
  module BuildValueClass
    def self.call(enum_values:, i18n_scope:, value_decorator:, machine: nil)
      aliases = machine&.instance_variable_get(:@aliases) || {}

      Class.new(String) do
        include(value_decorator) if value_decorator

        define_method(:machine) { machine } if machine

        def inspect
          "#<EnumMachine \"#{self}\">"
        end

        if machine&.transitions?
          def possible_transitions
            machine.possible_transitions(self)
          end

          def can?(enum_value)
            possible_transitions.include?(enum_value)
          end
        end

        enum_values.each do |enum_value|
          enum_name = enum_value.underscore

          define_method(:"#{enum_name}?") do
            self == enum_value
          end

          if machine&.transitions?
            define_method(:"can_#{enum_name}?") do
              possible_transitions.include?(enum_value)
            end
          end
        end

        aliases.each_key do |key|
          define_method(:"#{key}?") do
            machine.fetch_alias(key).include?(self)
          end
        end

        if i18n_scope
          full_scope = "enums.#{i18n_scope}"
          define_method(:human_name) do
            ::I18n.t(self, scope: full_scope, default: self)
          end
        end
      end
    end
  end
end
