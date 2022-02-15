# frozen_string_literal: true

RSpec.describe 'DriverActiveRecord', :ar do
  model =
    Class.new(TestModel) do
      enum_machine :color, %w[red green blue]
      enum_machine :state, %w[created approved cancelled activated cancelled] do
        transitions(
          'created'              => 'approved',
          %w[cancelled approved] => 'activated',
          %w[created approved]   => 'cancelled',
        )
        before_transition 'created' => 'approved' do |item|
          item.errors.add(:state, :invalid, message: 'invalid transition') if item.color.red?
        end
        after_transition 'created' => 'approved' do |item|
          item.message = 'after_approved'
        end
        after_transition %w[created cancelled] => %w[approved cancelled] do |item|
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
    expect(m.state.can_approved?).to eq true
    expect(m.state.can_cancelled?).to eq true
    expect(m.state.can_activated?).to eq false
  end

  it 'check possible_transitions method' do
    m = model.create(state: 'created', color: 'red')
    expect(m.state.possible_transitions).to eq %w[approved cancelled]
  end
end
