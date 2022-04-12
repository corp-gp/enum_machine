# frozen_string_literal: true

module EnumMachine
  class Machine

    attr_reader :enum_values

    def initialize(enum_values)
      @enum_values = enum_values
      @transitions = {}
      @before_transition = {}
      @after_transition = {}
      @aliases = {}
    end

    # public api
    # transitions('s1' => 's2', %w[s3 s3] => 's4')
    def transitions(from__to_hash)
      validate_state!(from__to_hash)

      from__to_hash.each do |from_arr, to|
        array_wrap(from_arr).each do |from|
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

      from, to = from__to_hash.to_a.first

      array_wrap(from).product(array_wrap(to)).each do |from_pair_to|
        next unless valid_transition!(from_pair_to)

        @before_transition[from_pair_to] ||= []
        @before_transition[from_pair_to] << block
      end
    end

    # public api
    # after_transition('s1' => 's4')
    # after_transition(%w[s1 s2] => %w[s3 s4])
    def after_transition(from__to_hash, &block)
      validate_state!(from__to_hash)

      from, to = from__to_hash.to_a.first

      array_wrap(from).product(array_wrap(to)).each do |from_pair_to|
        next unless valid_transition!(from_pair_to)

        @after_transition[from_pair_to] ||= []
        @after_transition[from_pair_to] << block
      end
    end

    # public api
    def any
      @any ||= enum_values.map { |s| AnyEnumValue.new(s) }
    end

    def aliases(hash)
      @aliases = hash
    end

    def transitions?
      @transitions.present?
    end

    # internal api
    def fetch_before_transitions(from__to)
      valid_transition!(from__to)
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

    private def valid_transition!(from_pair_to)
      from, to = from_pair_to
      is_valid_transition = @transitions[from]&.include?(to)

      if from.is_a?(AnyEnumValue) || to.is_a?(AnyEnumValue)
        is_valid_transition
      elsif is_valid_transition
        true
      else
        raise EnumMachine::Error, "transition #{from} => #{to} not defined in enum_machine"
      end
    end

    private def array_wrap(value)
      if value.nil?
        [nil]
      else
        Array(value)
      end
    end

    class AnyEnumValue < String

    end

  end
end
