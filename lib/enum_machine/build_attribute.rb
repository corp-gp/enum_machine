# frozen_string_literal: true

module EnumMachine
  module BuildAttribute

    def self.call(attr:, read_method:, enum_values:, i18n_scope:, machine: nil, aliases_keys: {})
      parent_attr = "@parent.#{read_method}"

      Class.new do
        def initialize(parent)
          @parent = parent
        end

        define_method(:machine) { machine } if machine

        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          # def to_s
          #   @parent.__state
          # end
          #
          # def inspect
          #   '<enum_machine :state>'
          # end
          #
          # def ==(other)
          #   raise EnumMachine::Error, "use `state.\#{other}?` instead `state == '\#{other}'`"
          # end

          def to_s
            #{parent_attr}
          end

          def inspect
            '<enum_machine :#{attr}>'
          end

          def ==(other)
            raise EnumMachine::Error, "use `#{attr}.\#{other}?` instead `#{attr} == '\#{other}'`"
          end
        RUBY

        enum_values.each do |enum_value|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def active?
            #   @parent.__state == 'active'
            # end
            #
            # def in?(values)
            #   values.include?(@parent.__state)
            # end

            def #{enum_value}?
              #{parent_attr} == '#{enum_value}'
            end

            def in?(values)
              values.include?(#{parent_attr})
            end
          RUBY

          if machine&.transitions?
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              # def can_active?
              #   machine.possible_transitions(@parent.__state).include?('canceled')
              # end
              #
              # def can?(enum_value)
              #  machine.possible_transitions(#{parent_attr}).include?(enum_value)
              # end
              #
              # def to_canceled!
              #  @parent.update!('state' => 'canceled')
              # end

              def can_#{enum_value}?
                machine.possible_transitions(#{parent_attr}).include?('#{enum_value}')
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

        if machine&.transitions?
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def possible_transitions
            #   machine.possible_transitions('active')
            # end

            def possible_transitions
              machine.possible_transitions(#{parent_attr})
            end
          RUBY
        end

        aliases_keys.each do |key|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def forming?
            #   @parent.class::State.forming.include?('active')
            # end

            def #{key}?
              @parent.class::State.#{key}.include?(#{parent_attr})
            end
          RUBY
        end

        if i18n_scope
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def i18n
            #   enum_value = @parent.__state
            #   ::I18n.t(enum_value, scope: "enums.product.state", default: enum_value)
            # end

            def i18n
              enum_value = #{parent_attr}
              ::I18n.t(enum_value, scope: "enums.#{i18n_scope}", default: enum_value)
            end
          RUBY
        end
      end
    end

  end
end
