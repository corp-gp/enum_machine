# frozen_string_literal: true

RSpec.describe "DriverActiveRecord", :ar do
  model =
    Class.new(TestModel) do
      enum_machine :state, %w[choice in_delivery]
      enum_machine :color, %w[red green blue]
    end

  it "check answer methods" do
    m = model.new(state: "choice", color: "red")

    expect(m.state).to be_choice
    expect(m.color).to be_red
    expect(m.state).not_to be_in_delivery
    expect(m.color).not_to be_blue
  end

  it "assign new value" do
    m = model.new(color: "red")
    expect(m.color).not_to be_blue

    m.color = "blue"
    expect(m.color).to be_blue
    expect(m.color.frozen?).to be true
  end

  it "works with custom value, not defined in enum list" do
    m = model.new(color: "wrong")

    expect(m.color).to eq("wrong")
    expect(m.color.red?).to be(false)
    expect(m.color.frozen?).to be true
    expect { m.color.wrong? }.to raise_error(NoMethodError)
  end

  it "test I18n" do
    I18n.load_path = Dir["#{File.expand_path('spec/locales')}/*.yml"]
    I18n.default_locale = :ru

    m = model.new(color: "red")
    expect(m.color.human_name).to eq "Красный"
    expect(model::COLOR.human_name_for("red")).to eq "Красный"
  end

  context "when enum in CamelCase" do
    model_camel =
      Class.new(TestModel) do
        enum_machine :state, %w[OrderCourier OrderPost]
      end

    it "check answer methods" do
      m = model_camel.new(state: "OrderCourier")

      expect(m.state).to be_order_courier
      expect(m.state).not_to be_order_post
    end

    it "returns state string" do
      expect(model_camel::STATE::ORDER_COURIER).to eq "OrderCourier"
      expect(model_camel::STATE::ORDER_COURIER__ORDER_POST).to eq %w[OrderCourier OrderPost]
    end
  end

  context "when enum applied on store field" do
    model_store =
      Class.new(TestModel) do
        store :params, accessors: [:fine_tuning], coder: JSON
        enum_machine :fine_tuning, %w[good excellent]
        enum_machine :state, %w[choice in_delivery]
      end

    it "set store field" do
      m = model_store.new(fine_tuning: "good", state: "choice")

      expect(m.fine_tuning).to be_good
      expect(m.fine_tuning).not_to be_excellent
    end
  end

  context "when with decorator" do
    let(:decorator_module) do
      Module.new do
        def am_i_choice?
          self == "choice"
        end
      end
    end

    let(:model_with_decorator) do
      decorator = decorator_module
      Class.new(TestModel) do
        enum_machine :state, %w[choice in_delivery], decorator: decorator
      end
    end

    it "decorates enum value for new record" do
      expect(model_with_decorator.new(state: "choice").state.am_i_choice?).to be(true)
      expect(model_with_decorator.new(state: "in_delivery").state.am_i_choice?).to be(false)
    end

    it "decorates enum value for existing record" do
      model_with_decorator.create(state: "choice")
      m = model_with_decorator.find_by(state: "choice")
      expect(m.state.am_i_choice?).to be(true)
    end
  end

  it "serialize model" do
    Object.const_set(:TestModelSerialize, model)
    m = TestModelSerialize.create(state: "choice", color: "wrong")

    unserialized_m = Marshal.load(Marshal.dump(m)) # rubocop:disable Gp/UnsafeYamlMarshal

    expect(unserialized_m.state).to be_choice
    expect(unserialized_m.class::STATE::CHOICE).to eq("choice")
    expect(unserialized_m.color).to eq("wrong")
    expect(unserialized_m.color.red?).to be(false)
  end

  it "test decorator" do
    decorating_model =
      Class.new(TestModel) do
        enum_machine :state, %w[choice in_delivery]
        include EnumMachine[color: { enum: %w[red green blue] }]
      end

    decorated_klass =
      Class.new do
        include decorating_model::STATE.decorator_module
        include decorating_model::COLOR.decorator_module
        attr_accessor :state, :color
      end

    decorated_item = decorated_klass.new
    decorated_item.state = "choice"
    decorated_item.color = "red"

    expect(decorated_item.state).to be_choice
    expect(decorated_item.color).to be_red
    expect(decorated_klass::STATE::CHOICE).to eq "choice"
    expect(decorated_klass::COLOR::RED).to eq "red"
  end

  it "returns state value by []" do
    expect(model::STATE["in_delivery"]).to eq "in_delivery"
    expect(model::STATE["in_delivery"].in_delivery?).to be(true)
    expect(model::STATE["in_delivery"].choice?).to be(false)
    expect(model::STATE["wrong"]).to be_nil
  end
end
