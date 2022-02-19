# frozen_string_literal: true

module EnumMachine
  class BuildClass

    attr_reader :values

    def initialize(values, aliases = {})
      @values = values
      @values.each { |v| memo_attr(v, v) }
      aliases.each { |k, v| memo_attr(k, v) }
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

      memo_attr(name_s, array_values)
    end

    def respond_to_missing?(name_s, include_all)
      name_s.include?('__') || super
    end

    private def memo_attr(name, value)
      self.class.attr_reader(name)
      instance_variable_set("@#{name}", value)
    end

  end
end
