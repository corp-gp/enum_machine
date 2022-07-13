# frozen_string_literal: true

module EnumMachine
  module DriverActiveRecord

    def enum_machine(attr, enum_values, i18n_scope: nil, &block)
      enum_module =
        Module.new do
          define_singleton_method(:included) do |klass|
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
            enum_value_klass_mapping = Hash.new { |hash, key| hash[key] = enum_value_klass.new(key) }
            klass.class_variable_set("@@#{attr}_attribute_mapping", enum_value_klass_mapping)

            enum_method =
              proc do
                enum_value = public_send("__#{attr}")
                return unless enum_value

                enum = instance_variable_get(:"@#{attr}_enum")

                unless enum == enum_value
                  enum = enum_value_klass_mapping[enum_value].dup
                  enum.parent = self
                  enum.freeze
                  instance_variable_set(:"@#{attr}_enum", enum)
                end

                enum
              end
            klass.class_variable_set(:"@@#{attr}_enum_method", enum_method)

            klass.define_singleton_method(:define_attribute_methods) do |*args|
              attribute_methods_generated = super(*args)

              if attribute_methods_generated
                generated_attribute_methods.synchronize do
                  class_variables.grep(/@@(.+)_enum_method/) do |var_name|
                    method_name = Regexp.last_match(1)
                    enum_method = class_variable_get(var_name)
                    klass.alias_method "__#{method_name}", method_name
                    klass.define_method(method_name, &enum_method)
                  end
                end
              end

              attribute_methods_generated
            end
          end
        end

      include enum_module
    end

  end
end
