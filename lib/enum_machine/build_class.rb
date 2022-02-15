# frozen_string_literal: true

module EnumMachine
  module BuildClass

    def self.call(enum_values)
      Class.new do |klass|
        klass.const_set :ENUM, enum_values
        attr_reader(*enum_values)

        def initialize
          self.class::ENUM.each do |enum_value|
            instance_variable_set("@#{enum_value}", enum_value)
          end
        end

        def values
          self.class::ENUM
        end

        def i18n_for(name)
          ::I18n.t(name, scope: "enums.#{i18n_scope}", default: name)
        end

        def method_missing(name)
          name_s = name.to_s
          return super unless name_s.include?('__')

          array_values = name_s.split('__').freeze

          unless (unexists_values = array_values - values).empty?
            raise EnumMachine::Error, "enums #{unexists_values} not exists"
          end

          self.class.attr_reader(name_s)
          instance_variable_set("@#{name_s}", array_values)
        end

        def respond_to_missing?(name_s, include_all)
          name_s.include?('__') || super
        end
      end
    end

  end
end
