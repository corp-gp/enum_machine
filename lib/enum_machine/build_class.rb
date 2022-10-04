# frozen_string_literal: true

module EnumMachine
  module BuildClass

    def self.call(enum_values:, i18n_scope:, machine: nil)
      aliases = machine&.instance_variable_get(:@aliases) || {}

      Class.new do
        define_singleton_method(:machine) { machine } if machine
        define_singleton_method(:values) { enum_values }

        if machine&.transitions?
          def self.skip_transitions(&block)
            machine.skip_transitions(&block)
          end
        end

        if i18n_scope
          def self.values_for_form(specific_values = nil) # rubocop:disable Gp/OptArgParameters
            (specific_values || values).map { |v| [human_name_for(v), v] }
          end

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def self.human_name_for(name)
            #   ::I18n.t(name, scope: "enums.test_model", default: name)
            # end

            def self.human_name_for(name)
              ::I18n.t(name, scope: "enums.#{i18n_scope}", default: name)
            end
          RUBY
        end

        enum_values.each do |enum_value|
          const_set enum_value.underscore.upcase, enum_value.freeze
        end

        aliases.each_key do |key|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # def self.forming
            #   @alias_forming ||= machine.fetch_alias('forming').freeze
            # end

            def self.#{key}
              @alias_#{key} ||= machine.fetch_alias('#{key}').freeze
            end
          RUBY
        end

        private_class_method def self.const_missing(name)
          name_s = name.to_s
          return super unless name_s.include?('__')

          const_set name_s, name_s.split('__').map { |i| const_get(i) }.freeze
        end
      end
    end

  end
end
