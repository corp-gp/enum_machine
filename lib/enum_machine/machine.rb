# frozen_string_literal: true

module EnumMachine
  class Machine

    attr_reader :enum_values, :base_klass, :enum_const_name

    def initialize(enum_values, base_klass = nil, enum_const_name = nil) # rubocop:disable Gp/OptArgParameters
      @enum_values = enum_values
      @base_klass = base_klass
      @enum_const_name = enum_const_name
      @transitions = {}
      @before_transition = {}
      @after_transition = {}
      @aliases = {}
    end

    # public api
    # transitions('s1' => 's2', %w[s3 s3] => 's4')
    def transitions(from__to_hash)
      validate_state!(from__to_hash)

      from__to_hash.each do |from_arr, to_arr|
        array_wrap(from_arr).product(array_wrap(to_arr)).each do |from, to|
          @transitions[from] ||= []
          @transitions[from] << to
        end
      end
    end

    # public api
    # before_transition('s1' => 's4')
    # before_transition(%w[s1 s2] => %w[s3 s4])
    def before_transition(from__to_hash, &block)
      validate_state!(from__to_hash)

      filter_transitions(from__to_hash).each do |from_pair_to|
        @before_transition[from_pair_to] ||= []
        @before_transition[from_pair_to] << block
      end
    end

    # public api
    # after_transition('s1' => 's4')
    # after_transition(%w[s1 s2] => %w[s3 s4])
    def after_transition(from__to_hash, &block)
      validate_state!(from__to_hash)

      filter_transitions(from__to_hash).each do |from_pair_to|
        @after_transition[from_pair_to] ||= []
        @after_transition[from_pair_to] << block
      end
    end

    # public api
    def any
      @any ||= AnyEnumValues.new(enum_values + [nil])
    end

    def aliases(hash)
      @aliases = hash
    end

    def fetch_aliases
      @aliases
    end

    def transitions?
      @transitions.present?
    end

    def fetch_transitions
      @transitions
    end

    # internal api
    def fetch_before_transitions(from__to)
      validate_transition!(from__to)
      @before_transition.fetch(from__to, [])
    end

    # internal api
    def fetch_after_transitions(from__to)
      @after_transition.fetch(from__to, [])
    end

    # internal api
    def fetch_alias(alias_key)
      array_wrap(@aliases.fetch(alias_key))
    end

    # internal api
    def possible_transitions(from)
      @transitions.fetch(from, [])
    end

    private def validate_state!(object_with_values)
      unless (undefined = object_with_values.to_a.flatten - enum_values - [nil]).empty?
        raise EnumMachine::Error, "values #{undefined} not defined in enum_machine"
      end
    end

    private def filter_transitions(from__to_hash)
      from_arr, to_arr = from__to_hash.to_a.first
      is_any_enum_values = from_arr.is_a?(AnyEnumValues) || to_arr.is_a?(AnyEnumValues)

      array_wrap(from_arr).product(array_wrap(to_arr)).filter do |from__to|
        if is_any_enum_values
          from, to = from__to
          possible_transitions(from).include?(to)
        else
          validate_transition!(from__to)
          true
        end
      end
    end

    private def validate_transition!(from__to)
      from, to = from__to
      unless possible_transitions(from).include?(to)
        raise EnumMachine::InvalidTransition.new(self, from, to)
      end
    end

    private def array_wrap(value)
      if value.nil?
        [nil]
      else
        Array(value)
      end
    end

    class AnyEnumValues < Array

    end

  end
end
