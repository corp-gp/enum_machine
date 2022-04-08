# frozen_string_literal: true

module EnumMachine
  module DriverActiveRecord

    def enum_machine(attr, enum_values, i18n_scope: nil, &block)
      klass = self

      attr_klass_name = attr.to_s.capitalize
      read_method = "_read_attribute('#{attr}')"
      i18n_scope ||= "#{klass.base_class.to_s.underscore}.#{attr}"

      machine = Machine.new(enum_values)
      machine.instance_eval(&block) if block
      aliases = machine.instance_variable_get(:@aliases)

      if machine.transitions?
        klass.class_variable_set("@@#{attr}_machine", machine)

        klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1 # rubocop:disable Style/DocumentDynamicEvalDefinition
          after_validation do
            unless (attr_changes = changes['#{attr}']).blank?
              @@#{attr}_machine.fetch_before_transitions(attr_changes).each { |i| i.call(self) }
            end
          end
          after_save do
            unless (attr_changes = previous_changes['#{attr}']).blank?
              @@#{attr}_machine.fetch_after_transitions(attr_changes).each { |i| i.call(self) }
            end
          end
        RUBY
      end

      klass.const_set attr_klass_name, BuildClass.new(enum_values, aliases: aliases, i18n_scope: i18n_scope)

      attribute_klass =
        BuildAttribute.call(
          attr:         attr,
          read_method:  read_method,
          enum_values:  enum_values,
          i18n_scope:   i18n_scope,
          machine:      machine,
          aliases_keys: aliases.keys,
        )
      klass.class_variable_set("@@#{attr}_attribute", attribute_klass)

      klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        # def state
        #   @state_enum ||= @@state_attribute.new(self)
        #   @state_enum.value = _read_attribute('state')
        #   @state_enum
        # end

        def #{attr}
          @#{attr}_enum ||= @@#{attr}_attribute.new(self)
          @#{attr}_enum.value = #{read_method}
          @#{attr}_enum
        end
      RUBY
    end

  end
end
