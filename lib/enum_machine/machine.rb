# frozen_string_literal: true

module EnumMachine
  class Machine

    attr_reader :enum_values

    def initialize(enum_values)
      @enum_values = enum_values
      @transitions = {}
      @before_transition = {}
      @after_transition = {}
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
      array_wrap(from).product(Array(to)).each do |from_pair_to|
        valid_transition!(from_pair_to)
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
      array_wrap(from).product(Array(to)).each do |from_pair_to|
        valid_transition!(from_pair_to)
        @after_transition[from_pair_to] ||= []
        @after_transition[from_pair_to] << block
      end
    end

    # public api
    def all
      enum_values
    end

    # internal api
    def blocks_for_before_transition(from__to)
      valid_transition!(from__to)
      @before_transition.fetch(from__to, [])
    end

    # internal api
    def blocks_for_after_transition(from__to)
      @after_transition.fetch(from__to, [])
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
      unless @transitions[from]&.include?(to)
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

  end
end
