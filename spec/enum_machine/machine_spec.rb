# frozen_string_literal: true

require 'rspec'

RSpec.describe EnumMachine::Machine do
  subject(:enum_machine) do
    m = described_class.new(%w[created approved cancelled activated])
    m.transitions(
      nil                    => 'created',
      'created'              => 'approved',
      %w[cancelled approved] => 'activated',
      %w[created approved]   => 'cancelled',
    )
    m
  end

  describe '#transitions' do
    it 'valid transitions map' do
      expected = {
        nil         => %w[created],
        'approved'  => %w[activated cancelled],
        'cancelled' => %w[activated],
        'created'   => %w[approved cancelled],
      }
      expect(enum_machine.instance_variable_get(:@transitions)).to eq(expected)
    end

    it 'raise when state undefined' do
      m = described_class.new(%w[s1 s2 s3])
      expect {
        m.transitions('s1' => 's2', %w[s2 s3] => 's4', %w[s5 s6] => 's7')
      }.to raise_error(EnumMachine::Error, 'values ["s4", "s5", "s6", "s7"] not defined in enum_machine')
    end
  end

  describe '#before_transition' do
    it 'finds before transition code blocks' do
      enum_machine.before_transition(%w[cancelled approved] => 'activated') { 1 }
      enum_machine.before_transition('approved' => 'activated') { 2 }

      expect(enum_machine.fetch_before_transitions(%w[approved activated]).map(&:call)).to eq [1, 2]
    end

    it 'raise when state undefined' do
      m = described_class.new(%w[s1 s2 s3])
      expect {
        m.before_transition(%w[s3 s4] => %w[s1 s5])
      }.to raise_error(EnumMachine::Error, 'values ["s4", "s5"] not defined in enum_machine')
    end
  end

  describe '#after_transition' do
    it 'finds after transition code blocks' do
      enum_machine.after_transition(%w[cancelled approved] => 'activated') { 1 }
      enum_machine.after_transition('approved' => 'activated') { 2 }

      expect(enum_machine.fetch_after_transitions(%w[approved activated]).map(&:call)).to eq [1, 2]
    end

    it 'raise when state undefined' do
      m = described_class.new(%w[s1 s2 s3])
      expect {
        m.after_transition(%w[s3 s4] => %w[s1 s5])
      }.to raise_error(EnumMachine::Error, 'values ["s4", "s5"] not defined in enum_machine')
    end
  end

  describe '#all' do
    it 'defines callbacks from any states' do
      enum_machine.before_transition(enum_machine.any => 'created')
      enum_machine.before_transition(enum_machine.any => 'activated')

      expect(enum_machine.instance_variable_get(:@before_transition).keys).to eq([[nil, 'created'], %w[approved activated], %w[cancelled activated]])
    end

    it 'defines callbacks to any states' do
      enum_machine.after_transition('created' => enum_machine.any)
      expect(enum_machine.instance_variable_get(:@after_transition).keys).to eq([%w[created approved], %w[created cancelled]])
    end
  end

  it 'finds before and after transition code blocks' do
    enum_machine.before_transition('approved' => 'activated') { 1 }
    enum_machine.after_transition('approved' => 'activated') { 2 }

    expect(enum_machine.fetch_before_transitions(%w[approved activated]).map(&:call)).to eq [1]
    expect(enum_machine.fetch_after_transitions(%w[approved activated]).map(&:call)).to eq [2]
  end

  describe '#possible_transitions' do
    it 'finds after transition code blocks' do
      expect(enum_machine.possible_transitions('created')).to eq %w[approved cancelled]
    end
  end

  describe '#skip_transitions' do
    it 'skips transition callbacks' do
      enum_machine.before_transition('approved' => 'activated') { 1 }
      enum_machine.after_transition('approved' => 'activated') { 2 }

      enum_machine.skip_transitions do
        expect(enum_machine.fetch_before_transitions(%w[approved activated]).map(&:call)).to eq []
        expect(enum_machine.fetch_after_transitions(%w[approved activated]).map(&:call)).to eq []
      end
    end

    it 'skips unavailable transition check' do
      enum_machine.skip_transitions do
        expect { enum_machine.fetch_before_transitions([nil, 'cancelled']) }
          .not_to raise_error
      end
    end

    it 'affects current thread only' do
      m = described_class.new(%w[s1])
      m.transitions(nil => 's1')
      m.before_transition(nil => 's1') { 1 }

      results = []

      threads = []
      threads << Thread.new do
        enum_machine.skip_transitions do
          results += m.fetch_before_transitions([nil, 's1']).map(&:call)
          sleep 0.2
        end
      end
      threads << Thread.new do
        sleep 0.1
        results += m.fetch_before_transitions([nil, 's1']).map(&:call)
      end

      threads.map(&:join)

      expect(results).to eq [1]
    end
  end
end
