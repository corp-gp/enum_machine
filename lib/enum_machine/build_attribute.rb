# frozen_string_literal: true

module EnumMachine
  module BuildAttribute

    def self.call(enum_values:, i18n_scope:, machine: nil)
      aliases = machine&.instance_variable_get(:@aliases) || {}

      Class.new(String) do
        define_method(:machine) { machine } if machine

        def self.inspect
          "EnumMachine:BuildAttribute:#{self}"
        end

        def inspect
          "#<#{self.class.inspect} value=#{self}>"
        end

        def value
          self
        end

        if machine&.transitions?
          def possible_transitions
            machine.possible_transitions(self)
          end

          def can?(check_enum_value)
            possible_transitions.include?(check_enum_value)
          end
        end

        enum_values.each do |check_enum_value|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def active?
            #   self == 'active'
            # end

            def #{check_enum_value}?
              self == '#{check_enum_value}'
            end
          RUBY

          if machine&.transitions?
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              # def can_active?
              #   possible_transitions.include?('canceled')
              # end

              def can_#{check_enum_value}?
                possible_transitions.include?('#{check_enum_value}')
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
      end
    end

  end
end
