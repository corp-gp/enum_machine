# frozen_string_literal: true

RSpec.describe 'DriverActiveRecord', :ar do
  model =
    Class.new(TestModel) do
      include EnumMachine[color: { enum: %w[red green blue] }]

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

  it 'serialize model' do
    Object.const_set :TestModelSerialize, model
    m = model.create(state: 'created', color: 'red')

    expect(m.state.created?).to eq(true) # state method call required

    unserialized_m = Marshal.load(Marshal.dump(m)) # rubocop:disable Gp/UnsafeYamlMarshal

    expect(unserialized_m.state.created?).to eq(true)
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
    expect { m.update(state: 'activated') }.to raise_error(EnumMachine::InvalidTransition) do |e|
      expect(e.message).to include('Transition "created" => "activated" not defined in enum_machine')
      expect(e.from).to eq 'created'
      expect(e.to).to eq 'activated'
      expect(e.enum_const.values).not_to be_empty
    end
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

  context 'when check skip transitions' do
    it 'create record if transition is skipped' do
      m = model.new(state: 'activated')

      m.skip_state_transitions { m.save! }

      expect(m.message).to eq nil

      expect { m.update(state: 'approved') }.to raise_error(EnumMachine::InvalidTransition) do |e|
        expect(e.message).to include('Transition "activated" => "approved" not defined in enum_machine')
      end
    end

    it 'checks skip context' do
      def a
        1
      end

      m = model.new(state: 'activated')

      expect { m.skip_state_transitions { a + 1 } }
        .not_to raise_error
    end

    it 'raise when simple create record' do
      expect { model.create(state: 'activated') }.to raise_error(EnumMachine::InvalidTransition) do |e|
        expect(e.from).to eq nil
        expect(e.message).to include('Transition nil => "activated" not defined in enum_machine')
      end
    end
  end

  it 'checks callbacks context' do
    semaphore =
      Class.new(TestModel) do
        enum_machine :color, %w[green orange red] do
          transitions(
            [nil, 'red'] => 'green',
            'green'      => 'orange',
            'orange'     => 'red',
          )
          before_transition 'green' => 'orange' do |item, from, to|
            item.message = "#{from} => #{to}"
          end
          before_transition 'orange' => 'red' do |item, _from, to|
            item.message = "#{item.color} => #{to}"
          end
          after_transition 'red' => 'green' do |item, _from, to|
            item.message = "#{item.color} => #{to}"
          end
        end
      end

    m = semaphore.create!(color: 'green')

    expect { m.update!(color: 'orange') }.to change(m, :message).to 'green => orange'
    expect { m.update!(color: 'red') }.to change(m, :message).to 'orange => red'
    expect { m.update!(color: 'green') }.to change(m, :message).to 'green => green'
  end
end
