# frozen_string_literal: true

module EnumMachine
  module BuildAttribute

    def self.call(attr:, read_method:, enum_values:, i18n_scope:, machine: nil, aliases_keys: {})
      parent_attr = "@parent.#{read_method}"

      Class.new(String) do
        define_method(:machine) { machine } if machine

        def initialize(parent)
          @parent = parent
        end

        def value=(enum_value)
          replace(enum_value.to_s)
        end

        enum_values.each do |enum_value|
          if machine&.transitions?
            def possible_transitions
              machine.possible_transitions(self)
            end
          end

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def active?
            #   self == 'active'
            # end
            #
            # def in?(values)
            #   values.include?(@parent.__state)
            # end

            def #{enum_value}?
              self == '#{enum_value}'
            end

            def in?(values)
              values.include?(self)
            end
          RUBY

          if machine&.transitions?
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              # def can_active?
              #   possible_transitions.include?('canceled')
              # end
              #
              # def can?(enum_value)
              #   machine.possible_transitions(@parent.__state).include?(enum_value)
              # end
              #
              # def to_canceled!
              #   @parent.update!('state' => 'canceled')
              # end

              def can_#{enum_value}?
                possible_transitions.include?('#{enum_value}')
              end

              def can?(enum_value)
                machine.possible_transitions(#{parent_attr}).include?(enum_value)
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
            #   @parent.class::State.forming.include?(self)
            # end

            def #{key}?
              @parent.class::State.#{key}.include?(self)
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
