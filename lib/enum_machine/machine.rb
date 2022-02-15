# frozen_string_literal: true

module EnumMachine
  class Machine

    def initialize
      @transitions = {}
      @before_transition = {}
      @after_transition = {}
    end

    # internal api
    def blocks_for_before_transition(from__to)
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

    # public api
    def transitions(from__to_hash)
      from__to_hash.each do |from_arr, to|
        Array(from_arr).each do |from|
          @transitions[from] ||= []
          @transitions[from] << to
        end
      end
    end

    # public api
    def before_transition(from__to_hash, &block)
      from, to = from__to_hash.to_a.first
      Array(from).product(Array(to)).each do |from_to_pair|
        @before_transition[from_to_pair] ||= []
        @before_transition[from_to_pair] << block
      end
    end

    # public api
    def after_transition(from__to_hash, &block)
      from, to = from__to_hash.to_a.first
      Array(from).product(Array(to)).each do |from_to_pair|
        @after_transition[from_to_pair] ||= []
        @after_transition[from_to_pair] << block
      end
    end

  end
end
