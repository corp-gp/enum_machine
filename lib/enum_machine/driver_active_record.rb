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

      enum_const_name = attr.to_s.upcase
      enum_klass = BuildClass.call(enum_values: enum_values, i18n_scope: i18n_scope, machine: machine)

      enum_value_klass = BuildAttribute.call(enum_values: enum_values, i18n_scope: i18n_scope, machine: machine)
      enum_value_klass.extend(AttributePersistenceMethods[attr, enum_values])

      # Hash.new with default_proc for working with custom values not defined in enum list
      value_attribute_mapping = Hash.new { |hash, enum_value| hash[enum_value] = enum_value_klass.new(enum_value).freeze }
      enum_klass.define_singleton_method(:value_attribute_mapping) { value_attribute_mapping }

      klass.const_set enum_const_name, enum_klass

      if machine.transitions?
        klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1 # rubocop:disable Style/DocumentDynamicEvalDefinition
          after_validation :__enum_machine_#{attr}_after_validation
          after_save :__enum_machine_#{attr}_after_save

          def __enum_machine_#{attr}_after_validation
            if (attr_changes = changes['#{attr}']) && !@__enum_machine_#{attr}_skip_transitions
              value_was, value_new = *attr_changes
              self.class::#{enum_const_name}.machine.fetch_before_transitions(attr_changes).each do |block|
                @__enum_machine_#{attr}_forced_value = value_was
                instance_exec(self, value_was, value_new, &block)
              ensure
                @__enum_machine_#{attr}_forced_value = nil
              end
            end
          end

          def __enum_machine_#{attr}_after_save
            if (attr_changes = previous_changes['#{attr}']) && !@__enum_machine_#{attr}_skip_transitions
              self.class::#{enum_const_name}.machine.fetch_after_transitions(attr_changes).each { |block| instance_exec(self, *attr_changes, &block) }
            end
          end
        RUBY
      end

      klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        # def state
        #   enum_value = @__enum_machine_state_forced_value || _read_attribute('state')
        #   return unless enum_value
        #
        #   unless @state_enum == enum_value
        #     @state_enum = self.class::STATE.value_attribute_mapping[enum_value].dup
        #     @state_enum.parent = self
        #     @state_enum.freeze
        #   end
        #
        #   @state_enum
        # end
        #
        # def skip_state_transitions
        #   @__enum_machine_state_skip_transitions = true
        #   yield
        # ensure
        #   @__enum_machine_state_skip_transitions = false
        # end

        def #{attr}
          enum_value = @__enum_machine_#{attr}_forced_value || #{read_method}
          return unless enum_value

          unless @#{attr}_enum == enum_value
            @#{attr}_enum = self.class::#{enum_const_name}.value_attribute_mapping[enum_value].dup
            @#{attr}_enum.parent = self
            @#{attr}_enum.freeze
          end

          @#{attr}_enum
        end

        def skip_#{attr}_transitions
          @__enum_machine_#{attr}_skip_transitions = true
          yield
        ensure
          @__enum_machine_#{attr}_skip_transitions = false
        end
      RUBY
    end

  end
end
