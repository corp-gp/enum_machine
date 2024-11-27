# frozen_string_literal: true

module EnumMachine
  module DriverActiveRecord
    def enum_machine(attr, enum_values, i18n_scope: nil, value_decorator: nil, &block)
      klass = self

      i18n_scope ||= "#{klass.base_class.to_s.underscore}.#{attr}"

      enum_const_name = attr.to_s.upcase
      machine = Machine.new(enum_values, klass, enum_const_name, attr)
      machine.instance_eval(&block) if block

      value_class = BuildValueClass.call(enum_values: enum_values, i18n_scope: i18n_scope, machine: machine, value_decorator: value_decorator)
      enum_class = BuildEnumClass.call(enum_values: enum_values, i18n_scope: i18n_scope, machine: machine, value_class: value_class)

      value_class.extend(AttributePersistenceMethods[attr, enum_values])

      # default_proc for working with custom values not defined in enum list but may exists in db
      enum_class.value_attribute_mapping.default_proc =
        proc do |hash, enum_value|
          hash[enum_value] = value_class.new(enum_value).freeze
        end

      if machine.transitions?
        klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1 # rubocop:disable Style/DocumentDynamicEvalDefinition
          before_save :__enum_machine_#{attr}_before_save
          after_save :__enum_machine_#{attr}_after_save

          def __enum_machine_#{attr}_before_save
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

      define_methods = Module.new
      define_methods.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        # def state
        #   enum_value = @__enum_machine_state_forced_value || super()
        #   return unless enum_value
        #
        #   unless @__enum_value_state == enum_value
        #     @__enum_value_state = self.class::STATE.value_attribute_mapping[enum_value].dup
        #     @__enum_value_state.parent = self
        #     @__enum_value_state.freeze
        #   end
        #
        #   @__enum_value_state
        # end
        #
        # def skip_state_transitions
        #   @__enum_machine_state_skip_transitions = true
        #   yield
        # ensure
        #   @__enum_machine_state_skip_transitions = false
        # end
        #
        # def initialize_dup(other)
        #   @__enum_value_state = nil
        #   super
        # end

        def #{attr}
          enum_value = @__enum_machine_#{attr}_forced_value || super()
          return unless enum_value

          unless @__enum_value_#{attr} == enum_value
            @__enum_value_#{attr} = self.class::#{enum_const_name}.value_attribute_mapping[enum_value].dup
            @__enum_value_#{attr}.parent = self
            @__enum_value_#{attr}.freeze
          end

          @__enum_value_#{attr}
        end

        def skip_#{attr}_transitions
          @__enum_machine_#{attr}_skip_transitions = true
          yield
        ensure
          @__enum_machine_#{attr}_skip_transitions = false
        end

        def initialize_dup(other)
          @__enum_value_#{attr} = nil
          super
        end
      RUBY

      enum_decorator =
        Module.new do
          define_singleton_method(:included) do |decorating_class|
            decorating_class.prepend define_methods
            decorating_class.const_set enum_const_name, enum_class
          end
        end
      enum_class.define_singleton_method(:enum_decorator) { enum_decorator }
      enum_class.define_singleton_method(:decorator_module) do
        puts "#decorator_module is deprecated and will be removed in next major release, use #enum_decorator instead"
        enum_decorator
      end

      klass.include(enum_decorator)

      enum_decorator
    end
  end
end
