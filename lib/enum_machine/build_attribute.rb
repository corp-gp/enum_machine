# frozen_string_literal: true

module EnumMachine
  module BuildAttribute

    def self.call(attr:, enum_values:, i18n_scope:, machine: nil, aliases_keys: [])
      Class.new(String) do
        define_method(:machine) { machine } if machine

        def initialize(parent, enum_value)
          @parent = parent
          replace(enum_value)
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
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def active?
            #   self == 'active'
            # end

            def #{enum_value}?
              self == '#{enum_value}'
            end
          RUBY

          if machine&.transitions?
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              # def can_active?
              #   possible_transitions.include?('canceled')
              # end
              #
              # def to_canceled!
              #   @parent.update!('state' => 'canceled')
              # end

              def can_#{enum_value}?
                possible_transitions.include?('#{enum_value}')
              end

              def to_#{enum_value}!
                @parent.update!('#{attr}' => '#{enum_value}')
              end
            RUBY
          end
        end

        aliases_keys.each do |key|
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
