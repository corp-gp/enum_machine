# frozen_string_literal: true

RSpec.describe 'DriverActiveRecord', :ar do
  model =
    Class.new(TestModel) do
      enum_machine :color, %w[red green blue]
      enum_machine :state, %w[created approved cancelled activated cancelled] do
        transitions(
          nil                    => 'created',
          'created'              => 'approved',
          %w[cancelled approved] => 'activated',
          %w[created approved]   => 'cancelled',
        )
        aliases(
          forming: %w[created approved],
        )
        before_transition 'created' => 'approved' do |item|
          item.errors.add(:state, :invalid, message: 'invalid transition') if item.color.red?
        end
        after_transition 'created' => 'approved' do |item|
          item.message = 'after_approved'
        end
        after_transition %w[created] => %w[approved cancelled] do |item|
          item.color = 'red'
        end
      end
    end

  it 'before_transition is runnable' do
    m = model.create(state: 'created', color: 'red')

    m.update(state: 'approved')

    expect(m.errors.messages).to eq({ state: ['invalid transition'] })
  end

  it 'after_transition is runnable' do
    m = model.create(state: 'created', color: 'green')

    m.state.to_approved!

    expect(m.message).to eq 'after_approved'
    expect(m.color.to_s).to eq 'red'
    expect(m.reload.message).to eq nil
    expect(m.color.to_s).to eq 'green'
  end

  it 'check can_ methods' do
    m = model.create(state: 'created', color: 'red')
    expect(m.state.can?('approved')).to eq true
    expect(m.state.can_approved?).to eq true
    expect(m.state.can_cancelled?).to eq true
    expect(m.state.can_activated?).to eq false
  end

  it 'check enum value comparsion' do
    m = model.new(state: 'created', color: 'red')

    expect(m.state.same?('created')).to be true
    expect(m.state.same?(model::State.created)).to be true

    expect(m.state.not_same?('created')).to be false
    expect(m.state.not_same?(model::State.created)).to be false

    expect(m.state.in?(%w[created])).to be true
  end

  it 'possible_transitions returns next states' do
    m = model.create(state: 'created', color: 'red')
    expect(m.state.possible_transitions).to eq %w[approved cancelled]
  end

  it 'raise when changed state is not defined in transitions' do
    m = model.create(state: 'created')
    expect { m.update(state: 'activated') }.to raise_error(EnumMachine::Error, 'transition created => activated not defined in enum_machine')
  end

  it 'test alias' do
    m = model.create(state: 'created')
    expect(m.state.forming?).to eq true
    expect(model::State.forming).to eq %w[created approved]
  end
end
