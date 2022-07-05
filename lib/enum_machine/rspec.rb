# frozen_string_literal: true

module EnumMachine
  module DriverActiveRecord # rubocop:disable Gp/ClassOrModuleDeclaredInWrongFile

    alias orig_enum_machine enum_machine
    def enum_machine(*attrs, &blk) # rubocop:disable Gp/ModuleMethodInWrongFile
      orig_enum_machine(*attrs, &blk)

      attr = attrs[0]
      class_eval <<~RUBY, __FILE__, __LINE__ + 1 # rubocop:disable Style/DocumentDynamicEvalDefinition
        attr_accessor :skip_create_transitions_for_#{attr}

        after_save do
          self.skip_create_transitions_for_#{attr} = nil
        end
      RUBY
    end
    ruby2_keywords :enum_machine

  end
end
