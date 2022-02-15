# frozen_string_literal: true

require 'rspec'

RSpec.describe EnumMachine::Machine do
  subject(:item) do
    m = described_class.new
    m.transitions(
      'created'              => 'approved',
      %w[cancelled approved] => 'activated',
      %w[created approved]   => 'cancelled',
    )
    m
  end

  describe '#transitions' do
    it 'valid transitions map' do
      expected = {
        'approved'  => %w[activated cancelled],
        'cancelled' => %w[activated],
        'created'   => %w[approved cancelled],
      }
      expect(item.instance_variable_get(:@transitions)).to eq(expected)
    end
  end

  describe '#blocks_for_before_transition' do
    it 'finds before transition code blocks' do
      item.before_transition(%w[cancelled approved] => 'activated') { 1 }
      item.before_transition('approved' => 'activated') { 2 }

      expect(item.blocks_for_before_transition(%w[approved activated]).map(&:call)).to eq [1, 2]
    end
  end

  describe '#blocks_for_afrer_transition' do
    it 'finds after transition code blocks' do
      item.after_transition(%w[cancelled approved] => 'activated') { 1 }
      item.after_transition('approved' => 'activated') { 2 }

      expect(item.blocks_for_after_transition(%w[approved activated]).map(&:call)).to eq [1, 2]
    end
  end

  it 'finds before and after transition code blocks' do
    item.before_transition('approved' => 'activated') { 1 }
    item.after_transition('approved' => 'activated') { 2 }

    expect(item.blocks_for_before_transition(%w[approved activated]).map(&:call)).to eq [1]
    expect(item.blocks_for_after_transition(%w[approved activated]).map(&:call)).to eq [2]
  end

  describe '#possible_transitions' do
    it 'finds after transition code blocks' do
      expect(item.possible_transitions('created')).to eq %w[approved cancelled]
    end
  end
end
