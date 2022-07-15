# frozen_string_literal: true

RSpec.describe 'DriverActiveRecord', :ar do
  model =
    Class.new(TestModel) do
      enum_machine :state, %w[choice in_delivery]
      enum_machine :color, %w[red green blue]
    end

  it 'check answer methods' do
    m = model.new(state: 'choice', color: 'red')

    expect(m.state).to be_choice
    expect(m.color).to be_red
    expect(m.state).not_to be_in_delivery
    expect(m.color).not_to be_blue
  end

  it 'assign new value' do
    m = model.new(color: 'red')
    expect(m.color).not_to be_blue

    m.color = 'blue'
    expect(m.color).to be_blue
    expect(m.color.frozen?).to eq true
  end

  it 'works with custom value, not defined in enum list' do
    m = model.new(color: 'wrong')

    expect(m.color).to eq('wrong')
    expect(m.color.red?).to eq(false)
    expect(m.color.frozen?).to eq true
    expect { m.color.wrong? }.to raise_error(NoMethodError)
  end

  it 'pretty print inspect' do
    m = model.new(state: 'choice')
    expect(m.state.inspect).to match(/EnumMachine:BuildAttribute.+value=choice parent=/)
  end

  it 'test I18n' do
    I18n.load_path = Dir["#{File.expand_path('spec/locales')}/*.yml"]
    I18n.default_locale = :ru

    m = model.new(color: 'red')
    expect(m.color.human_name).to eq 'Красный'
    expect(model::COLOR.human_name_for('red')).to eq 'Красный'
  end

  context 'when enum in CamelCase' do
    model_camel =
      Class.new(TestModel) do
        enum_machine :state, %w[OrderCourier OrderPost]
      end

    it 'check answer methods' do
      m = model_camel.new(state: 'OrderCourier')

      expect(m.state).to be_order_courier
      expect(m.state).not_to be_order_post
    end

    it 'returns state string' do
      expect(model_camel::STATE::ORDER_COURIER).to eq 'OrderCourier'
      expect(model_camel::STATE::ORDER_COURIER__ORDER_POST).to eq %w[OrderCourier OrderPost]
    end
  end

  context 'when enum applied on store field' do
    model_store =
      Class.new(TestModel) do
        store :params, accessors: [:fine_tuning], coder: JSON
        enum_machine :fine_tuning, %w[good excellent]
        enum_machine :state, %w[choice in_delivery]
      end

    it 'set store field' do
      m = model_store.new(fine_tuning: 'good', state: 'choice')

      expect(m.fine_tuning).to be_good
      expect(m.fine_tuning).not_to be_excellent
    end
  end
end
