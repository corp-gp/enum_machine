# frozen_string_literal: true

module EnumMachine
  class BuildClass

    attr_reader :values, :i18n_scope

    def initialize(values, i18n_scope:, aliases: {})
      @i18n_scope = i18n_scope
      @values = values
      @values.each { |v| memo_attr(v, v) }
      aliases.each { |k, v| memo_attr(k, v) }
    end

    def human_name_for(name)
      ::I18n.t(name, scope: "enums.#{i18n_scope}", default: name)
    end

    def values_for_form
      values.map { |v| [human_name_for(v), v] }
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
