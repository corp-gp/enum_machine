# frozen_string_literal: true

module EnumMachine
  module BuildAttribute

    def self.call(enum_values:, i18n_scope:, machine: nil)
      aliases = machine&.instance_variable_get(:@aliases) || {}

      Class.new do
        define_method(:machine) { machine } if machine

        delegate :==, :to_str, :eql?, :to_s, to: :enum_value
        attr_reader :enum_value

        def initialize(enum_value)
          @enum_value = enum_value
        end

        if machine&.transitions?
          def possible_transitions
            machine.possible_transitions(enum_value)
          end

          def can?(check_enum_value)
            possible_transitions.include?(check_enum_value)
          end
        end

        enum_values.each do |check_enum_value|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def active?
            #   enum_value == 'active'
            # end

            def #{check_enum_value}?
              enum_value == '#{check_enum_value}'
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
            #   machine.fetch_alias('forming').include?(enum_value)
            # end

            def #{key}?
              machine.fetch_alias('#{key}').include?(enum_value)
            end
          RUBY
        end

        if i18n_scope
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def human_name
            #   ::I18n.t(enum_value, scope: "enums.product.state", default: enum_value)
            # end

            def human_name
              ::I18n.t(enum_value, scope: "enums.#{i18n_scope}", default: enum_value)
            end
          RUBY
        end
      end
    end

  end
end
