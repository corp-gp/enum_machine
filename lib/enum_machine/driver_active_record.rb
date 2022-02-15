# frozen_string_literal: true

module EnumMachine
  module DriverActiveRecord

    def enum_machine(attr, enum_values, i18n_scope: nil, &block)
      klass = self

      attr_klass_name = attr.to_s.capitalize
      attribute_const = "#{attr_klass_name}Attribute"
      read_method = "_read_attribute('#{attr}')"
      i18n_scope ||= "#{klass.base_class.to_s.underscore}.#{attr}"

      machine_const = nil
      if block
        machine_const = "#{attr_klass_name}Machine"
        m = Machine.new
        m.instance_eval(&block)
        const_set machine_const, m

        klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1 # rubocop:disable Style/DocumentDynamicEvalDefinition
          after_validation do
            unless (attr_changes = changes['#{attr}']).blank?
              #{machine_const}.blocks_for_before_transition(attr_changes).map { |i| i.call(self) }
            end
          end
          after_save do
            unless (attr_changes = previous_changes['#{attr}']).blank?
              #{machine_const}.blocks_for_after_transition(attr_changes).map { |i| i.call(self) }
            end
          end
        RUBY
      end

      const_set attribute_const, BuildAttribute.call(
        attr:            attr,
        read_method:     read_method,
        enum_values:     enum_values,
        i18n_scope:      i18n_scope,
        attribute_const: attribute_const,
        machine_const:   machine_const,
      )

      klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        # def state
        #   @state_enum ||= StateAttribute.new(self)
        # end

        def #{attr}
          @#{attr}_enum ||= #{attribute_const}.new(self)
        end
      RUBY

      klass.const_set attr_klass_name, BuildClass.call(enum_values).new
    end

  end
end
