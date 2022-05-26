# frozen_string_literal: true

require 'enum_machine/rspec'

RSpec.describe 'DriverActiveRecord', :ar do
  model =
    Class.new(TestModel) do
      enum_machine :color, %w[red green blue]
      enum_machine :state, %w[created approved cancelled activated cancelled] do
        transitions(
          nil                    => 'created',
          'created'              => [nil, 'approved'],
          %w[cancelled approved] => 'activated',
          'activated'            => %w[created cancelled],
        )
        aliases(
          'forming' => %w[created approved],
          'pending' => nil,
        )
        before_transition 'created' => 'approved' do |item|
          item.errors.add(:state, :invalid, message: 'invalid transition') if item.color.red?
        end
        after_transition 'created' => 'approved' do |item|
          item.message = 'after_approved'
        end
        after_transition %w[created] => %w[approved] do |item|
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
    expect(m.color).to eq 'red'

    m.reload

    expect(m.message).to eq nil
    expect(m.color).to eq 'green'
  end

  it 'check can_ methods' do
    m = model.new(state: 'created', color: 'red')
    expect(m.state.can?('approved')).to eq true
    expect(m.state.can_approved?).to eq true
    expect(m.state.can_cancelled?).to eq false
    expect(m.state.can_activated?).to eq false
  end

  it 'check enum value comparsion' do
    m = model.new(state: 'created', color: 'red')

    expect(m.state).to eq 'created'
    expect(m.state).to eq model::STATE::CREATED
    expect(model::STATE::CREATED).to eq 'created'
    expect({ m.state => 1 }['created']).to eq 1

    m.state = nil
    expect(m.state).to eq nil
  end

  it 'possible_transitions returns next states' do
    expect(model.new(state: 'created').state.possible_transitions).to eq [nil, 'approved']
    expect(model.new(state: 'activated').state.possible_transitions).to eq %w[created cancelled]
  end

  it 'raise when changed state is not defined in transitions' do
    m = model.create(state: 'created')
    expect { m.update(state: 'activated') }.to raise_error(EnumMachine::Error, 'transition "created" => "activated" not defined in enum_machine')
  end

  it 'test alias' do
    m = model.new(state: 'created')

    expect(m.state.forming?).to eq true
    expect(model::STATE.forming).to eq %w[created approved]
  end

  it 'coerces states type' do
    state_enum = model.new(state: 'created').state
    expect(model.new(message: state_enum).message).to eq 'created'
  end

  context 'when state is changed' do
    it 'returns changed state string' do
      m = model.create(state: 'created')
      state_was = m.state

      m.state = 'approved'

      expect(m.state).to eq 'approved'
      expect(state_was).to eq 'created'
    end
  end

  context 'when rails test environment' do
    it 'create record if transition is skipped' do
      m = model.create(state: 'activated', skip_create_transitions_for_state: true)

      expect(m.message).to eq nil

      expect {
        m.update!(state: 'approved')
      }.to raise_error(EnumMachine::Error, 'transition "activated" => "approved" not defined in enum_machine')
    end

    it 'raise when simple create record' do
      expect {
        model.create(state: 'activated')
      }.to raise_error(EnumMachine::Error, 'transition nil => "activated" not defined in enum_machine')
    end
  end

  it 'checks callbacks context' do
    Semaphore =
      Class.new(TestModel) do
        enum_machine :color, %w[green orange red] do
          transitions(
            [nil, 'red'] => 'green',
            'green'      => 'orange',
            'orange'     => 'red',
            )
          after_transition any => 'green' do
            self.message = 'Go!'
          end
          before_transition any => any do |item, from, to|
            item.message = "#{from} => #{to}"
          end
        end
      end

    semaphore = Semaphore.new

    expect { semaphore.update!(color: 'green') }.to change(semaphore, :message).to 'Go!'
    expect { semaphore.update!(color: 'orange') }.to change(semaphore, :message).to 'green => orange'
  end
end
