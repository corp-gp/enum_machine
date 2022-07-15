# frozen_string_literal: true

module EnumMachine
  module DriverActiveRecord

    def enum_machine(attr, enum_values, i18n_scope: nil, &block)
      klass = self

      store_attr = klass.stored_attributes.find { |_k, v| v.include?(attr.to_sym) }&.first
      read_method =
        if store_attr
          "read_store_attribute('#{store_attr}', '#{attr}')"
        else
          "_read_attribute('#{attr}')"
        end
      i18n_scope ||= "#{klass.base_class.to_s.underscore}.#{attr}"

      machine = Machine.new(enum_values)
      machine.instance_eval(&block) if block

      if machine.transitions?
        klass.class_variable_set("@@#{attr}_machine", machine)

        skip_cond = "&& !skip_create_transitions_for_#{attr}" if defined?(Rails) && Rails.env.test?
        klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1 # rubocop:disable Style/DocumentDynamicEvalDefinition
          after_validation do
            if (attr_changes = changes['#{attr}']) #{skip_cond}
              @@#{attr}_machine.fetch_before_transitions(attr_changes).each { |block| instance_exec(self, *attr_changes, &block) }
            end
          end

          after_save do
            if (attr_changes = previous_changes['#{attr}']) #{skip_cond}
              @@#{attr}_machine.fetch_after_transitions(attr_changes).each { |block| instance_exec(self, *attr_changes, &block) }
            end
          end
        RUBY
      end

      enum_const_name = attr.to_s.upcase
      enum_klass = BuildClass.call(enum_values: enum_values, i18n_scope: i18n_scope, machine: machine)
      klass.const_set enum_const_name, enum_klass

      enum_value_klass = BuildAttribute.call(enum_values: enum_values, i18n_scope: i18n_scope, machine: machine)
      enum_value_klass.extend(AttributePersistenceMethods[attr, enum_values])

      # Hash.new with default_proc for working with custom values not defined in enum list
      enum_value_klass_mapping = Hash.new { |hash, key| hash[key] = enum_value_klass.new(key).freeze }
      klass.class_variable_set("@@#{attr}_attribute_mapping", enum_value_klass_mapping)

      klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        # def state
        #   enum_value = _read_attribute('state')
        #   return unless enum_value
        #
        #   unless @state_enum == enum_value
        #     @state_enum = @@state_attribute_mapping[enum_value].dup
        #     @state_enum.parent = self
        #     @state_enum.freeze
        #   end
        #
        #   @state_enum
        # end

        def #{attr}
          enum_value = #{read_method}
          return unless enum_value

          unless @#{attr}_enum == enum_value
            @#{attr}_enum = @@#{attr}_attribute_mapping[enum_value].dup
            @#{attr}_enum.parent = self
            @#{attr}_enum.freeze
          end

          @#{attr}_enum
        end
      RUBY
    end

  end
end
