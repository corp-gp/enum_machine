# frozen_string_literal: true

require "rspec"

RSpec.describe EnumMachine::Machine do
  subject(:item) do
    m = described_class.new(%w[created approved cancelled activated])
    m.transitions(
      nil                    => "created",
      "created"              => "approved",
      %w[cancelled approved] => "activated",
      %w[created approved]   => "cancelled",
    )
    m
  end

  describe "#transitions" do
    it "valid transitions map" do
      expected = {
        nil         => %w[created],
        "approved"  => %w[activated cancelled],
        "cancelled" => %w[activated],
        "created"   => %w[approved cancelled],
      }
      expect(item.instance_variable_get(:@transitions)).to eq(expected)
    end

    it "raise when state undefined" do
      m = described_class.new(%w[s1 s2 s3])
      expect {
        m.transitions("s1" => "s2", %w[s2 s3] => "s4", %w[s5 s6] => "s7")
      }.to raise_error(EnumMachine::Error, 'values ["s4", "s5", "s6", "s7"] not defined in enum_machine')
    end
  end

  describe "#before_transition" do
    it "finds before transition code blocks" do
      item.before_transition(%w[cancelled approved] => "activated") { 1 }
      item.before_transition("approved" => "activated") { 2 }

      expect(item.fetch_before_transitions(%w[approved activated]).map(&:call)).to eq [1, 2]
    end

    it "raise when state undefined" do
      m = described_class.new(%w[s1 s2 s3])
      expect {
        m.before_transition(%w[s3 s4] => %w[s1 s5])
      }.to raise_error(EnumMachine::Error, 'values ["s4", "s5"] not defined in enum_machine')
    end
  end

  describe "#after_transition" do
    it "finds after transition code blocks" do
      item.after_transition(%w[cancelled approved] => "activated") { 1 }
      item.after_transition("approved" => "activated") { 2 }

      expect(item.fetch_after_transitions(%w[approved activated]).map(&:call)).to eq [1, 2]
    end

    it "raise when state undefined" do
      m = described_class.new(%w[s1 s2 s3])
      expect {
        m.after_transition(%w[s3 s4] => %w[s1 s5])
      }.to raise_error(EnumMachine::Error, 'values ["s4", "s5"] not defined in enum_machine')
    end
  end

  describe "#all" do
    it "defines callbacks from any states" do
      item.before_transition(item.any => "created")
      item.before_transition(item.any => "activated")

      expect(item.instance_variable_get(:@before_transition).keys).to eq([[nil, "created"], %w[approved activated], %w[cancelled activated]])
    end

    it "defines callbacks to any states" do
      item.after_transition("created" => item.any)
      expect(item.instance_variable_get(:@after_transition).keys).to eq([%w[created approved], %w[created cancelled]])
    end
  end

  it "finds before and after transition code blocks" do
    item.before_transition("approved" => "activated") { 1 }
    item.after_transition("approved" => "activated") { 2 }

    expect(item.fetch_before_transitions(%w[approved activated]).map(&:call)).to eq [1]
    expect(item.fetch_after_transitions(%w[approved activated]).map(&:call)).to eq [2]
  end

  describe "#possible_transitions" do
    it "finds after transition code blocks" do
      expect(item.possible_transitions("created")).to eq %w[approved cancelled]
    end
  end
end
