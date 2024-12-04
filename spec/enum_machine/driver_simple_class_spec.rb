# frozen_string_literal: true

class TestClass
  attr_accessor :state

  def initialize(state)
    @state = state
  end

  include EnumMachine[state: { enum: %w[choice in_delivery] }]
end

module ValueDecorator
  def am_i_choice?
    self == "choice"
  end
end

class TestClassWithDecorator
  attr_accessor :state

  def initialize(state)
    @state = state
  end

  include EnumMachine[state: { enum: %w[choice in_delivery], value_decorator: ValueDecorator }]
end

RSpec.describe "DriverSimpleClass" do
  subject(:item) { TestClass.new("choice") }

  it { expect(item.state).to be_choice }
  it { expect(item.state).not_to be_in_delivery }
  it { expect(item.state).to eq "choice" }
  it { expect(item.state.frozen?).to be true }

  describe "module" do
    it "returns state string" do
      expect(TestClass::STATE::IN_DELIVERY).to eq "in_delivery"
      expect(TestClass::STATE::IN_DELIVERY).to be_frozen
    end

    it "returns state array" do
      expect(TestClass::STATE::CHOICE__IN_DELIVERY).to eq %w[choice in_delivery]
      expect(TestClass::STATE::CHOICE__IN_DELIVERY).to be_frozen
    end

    it "raise exceptions unexists state" do
      expect { TestClass::STATE::CHOICE__CANCELLED }.to raise_error(NameError, "uninitialized constant TestClass::STATE::CANCELLED")
    end

    it "pretty print errors" do
      expect { item.state.human_name }.to raise_error(NoMethodError, /undefined method/)
    end

    context "when state is changed" do
      it "returns changed state string" do
        item.state = "choice"
        state_was = item.state

        item.state = "in_delivery"

        expect(item.state).to eq "in_delivery"
        expect(state_was).to eq "choice"
      end
    end
  end

  describe "TestClass::STATE const" do
    it "#values" do
      expect(TestClass::STATE.values).to eq(%w[choice in_delivery])
    end

    it "#[]" do
      expect(TestClass::STATE["in_delivery"]).to eq "in_delivery"
      expect(TestClass::STATE["in_delivery"].in_delivery?).to be(true)
      expect(TestClass::STATE["in_delivery"].choice?).to be(false)
      expect(TestClass::STATE["wrong"]).to be_nil
    end

    it "#enum_decorator" do
      decorated_klass =
        Class.new do
          include TestClassWithDecorator::STATE.enum_decorator
          attr_accessor :state
        end

      decorated_item = decorated_klass.new
      decorated_item.state = "choice"

      expect(decorated_item.state).to be_choice
      expect(decorated_klass::STATE::CHOICE).to eq "choice"
    end
  end

  context "when definition order is changed" do
    let(:invert_definition_class) do
      Class.new do
        include EnumMachine[state: { enum: %w[choice in_delivery] }]
        attr_accessor :state
      end
    end

    it "nothing raised" do
      expect { invert_definition_class }.not_to raise_error

      item = invert_definition_class.new
      item.state = "choice"

      expect(item.state).to be_choice
    end
  end

  context "when with decorator" do
    it "decorates enum values" do
      expect(TestClassWithDecorator.new("choice").state.am_i_choice?).to be(true)
      expect(TestClassWithDecorator.new("in_delivery").state.am_i_choice?).to be(false)
    end

    it "decorates enum values in enum const" do
      expect(TestClassWithDecorator::STATE.values.map(&:am_i_choice?)).to eq([true, false])
      expect((TestClassWithDecorator::STATE.values & ["in_delivery"]).map(&:am_i_choice?)).to eq([false])
    end

    it "keeps decorating on serialization" do
      m = TestClassWithDecorator.new("choice")
      unserialized_m = Marshal.load(Marshal.dump(m))
      expect(unserialized_m.state.am_i_choice?).to be(true)
    end

    it "keeps decorating on #enum_decorator" do
      decorated_klass =
        Class.new do
          include TestClassWithDecorator::STATE.enum_decorator
          attr_accessor :state
        end

      decorated_item = decorated_klass.new
      decorated_item.state = "choice"

      expect(decorated_item.state.am_i_choice?).to be(true)
    end
  end

  it "serialize class" do
    m = TestClass.new("choice")

    unserialized_m = Marshal.load(Marshal.dump(m))

    expect(unserialized_m.state).to be_choice
    expect(unserialized_m.class::STATE::CHOICE).to eq "choice"
  end

  it "serialize value" do
    value = TestClass::STATE["choice"]
    value_after_serialize = Marshal.load(Marshal.dump(value))

    expect(value_after_serialize).to eq(value)
    expect(value_after_serialize.choice?).to be(true)
  end
end
