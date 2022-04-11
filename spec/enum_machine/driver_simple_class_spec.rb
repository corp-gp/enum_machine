# frozen_string_literal: true

RSpec.describe 'DriverSimpleClass' do
  klass =
    Class.new do
      attr_accessor :state

      def initialize(state)
        @state = state
      end

      include EnumMachine[state: { enum: %w[choice in_delivery] }]
    end

  subject(:item) { klass.new('choice') }

  it { expect(item.state).to be_choice }
  it { expect(item.state).not_to be_in_delivery }
  it { expect(item.state).to eq 'choice' }

  describe 'module' do
    it 'returns state string' do
      expect(klass::State.in_delivery).to eq 'in_delivery'
      expect(klass::State.in_delivery).to be_frozen
    end

    it 'returns state array' do
      expect(klass::State.choice__in_delivery).to eq %w[choice in_delivery]
      expect(klass::State.choice__in_delivery).to be_frozen
    end

    it 'raise exceptions unexists state' do
      expect { klass::State.choice__cancelled }.to raise_error(EnumMachine::Error, 'enums ["cancelled"] not exists')
    end

    context 'when state is changed' do
      it 'returns changed state string' do
        item.state = 'choice'
        state_was = item.state

        item.state = 'in_delivery'

        expect(item.state).to eq 'in_delivery'
        expect(state_was).to eq 'choice'
      end
    end
  end
end
