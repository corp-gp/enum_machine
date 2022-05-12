# frozen_string_literal: true

RSpec.describe 'DriverActiveRecord', :ar do
  model =
    Class.new(TestModel) do
      def callback_log
        @callback_log ||= []
      end

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
        after_transition %w[created] => %w[approved] do |item|
          item.color = 'red'
        end
        before_transition any => any do |item, from, to|
          item.callback_log << "before_#{from}_#{to}"
        end
        after_transition any => any do |item, from, to|
          item.callback_log << "after_#{from}_#{to}"
        end
      end
    end

  it 'before_transition is runnable' do
    m = model.create(state: 'created', color: 'red')

    m.update(state: 'approved')
    expect(m.errors.messages).to eq({ state: ['invalid transition'] })

    expect(m.callback_log).to include('before_created_approved')
    expect(m.callback_log).not_to include('after_created_approved')
  end

  it 'after_transition is runnable' do
    m = model.create(state: 'created', color: 'green')

    m.state.to_approved!

    expect(m.callback_log).to include('after_created_approved')
  end

  it 'allow disable machine' do
    m = model.create(state: 'created', color: 'red')

    expect {
      model::STATE.machine.disable { m.state.to_approved! }
    }.not_to change(m, :callback_log)

    m.reload

    expect(m.state).to eq 'approved'
    expect(m.color).to eq 'red'
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
end
