# frozen_string_literal: true

module EnumMachine
  module BuildValueClass
    def self.call(enum_values:, i18n_scope:, value_decorator:, machine: nil)
      aliases = machine&.instance_variable_get(:@aliases) || {}

      Class.new(String) do
        include(value_decorator) if value_decorator

        define_method(:machine) { machine }
        define_method(:enum_values) { enum_values }
        private :enum_values, :machine

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

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def active?
            #   self == 'active'
            # end

            def #{enum_name}?
              self == '#{enum_value}'
            end
          RUBY

          if machine&.transitions?
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              # def can_active?
              #   possible_transitions.include?('canceled')
              # end

              def can_#{enum_name}?
                possible_transitions.include?('#{enum_value}')
              end
            RUBY
          end
        end

        aliases.each_key do |key|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def forming?
            #   machine.fetch_alias('forming').include?(self)
            # end

            def #{key}?
              machine.fetch_alias('#{key}').include?(self)
            end
          RUBY
        end

        if i18n_scope
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def human_name
            #   ::I18n.t(self, scope: "enums.product.state", default: self)
            # end

            def human_name
              ::I18n.t(self, scope: "enums.#{i18n_scope}", default: self)
            end
          RUBY
        end

        def respond_to_missing?(method_name, _include_private = false)
          method_name = method_name.name if method_name.is_a?(Symbol)

          method_name.end_with?("?") &&
            method_name.include?("__") &&
            (method_name.delete_suffix("?").split("__") - enum_values).empty?
        end

        def method_missing(method_name)
          return super unless respond_to_missing?(method_name)

          m_enums = method_name.name.delete_suffix("?").split("__")
          self.class.define_method(method_name) { m_enums.include?(self) }
          send(method_name)
        end
      end
    end
  end
end
