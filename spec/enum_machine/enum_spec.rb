# frozen_string_literal: true

module StandaloneDecorator
  def hex
    self == "red" ? "#ff0000" : "#00ff00"
  end
end

RSpec.describe EnumMachine, ".enum" do
  let(:color) { described_class.enum(%w[red green], i18n_scope: "test_model.color", value_decorator: StandaloneDecorator) }

  it { expect(color.values).to eq %w[red green] }
  it { expect(color::RED).to eq "red" }
  it { expect(color::RED.red?).to be true }
  it { expect(color::RED.green?).to be false }
  it { expect(color::RED.red__green?).to be true }
  it { expect(color::RED__GREEN).to eq %w[red green] }
  it { expect(color["green"].green?).to be true }
  it { expect(color[:green].green?).to be true }
  it { expect(color["blue"]).to be_nil }
  it { expect(color[:blue]).to be_nil }
  it { expect(color::RED.hex).to eq "#ff0000" }
  it { expect(color::RED.human_name).to eq "Красный" }
  it { expect(color.human_name_for("red")).to eq "Красный" }
  it { expect(color.values_for_form).to eq [%w[Красный red], %w[green green]] }

  context "without optional arguments" do
    let(:simple_enum) { described_class.enum(%w[active inactive]) }

    it { expect(simple_enum.values).to eq %w[active inactive] }
    it { expect(simple_enum::ACTIVE.active?).to be true }
    it { expect(simple_enum["active"].active?).to be true }
    it { expect(simple_enum[:active].active?).to be true }
  end

  describe "#enum_decorator" do
    before(:each) do
      stub_const("Color", described_class.enum(%w[red green], i18n_scope: "test_model.color", value_decorator: StandaloneDecorator))
      stub_const(
        "DecoratedClass",
        Class.new do
          include Color.enum_decorator

          attr_accessor :color
        end,
      )
    end

    it "decorates plain class" do
      item = DecoratedClass.new
      item.color = "red"

      expect(item.color).to be_red
      expect(item.color).not_to be_green
      expect(item.color.hex).to eq "#ff0000"
      expect(item.color.human_name).to eq "Красный"
      expect(DecoratedClass::COLOR::RED).to eq "red"
    end

    it "decorates active record model", :ar do
      stub_const(
        "DecoratedModel",
        Class.new(TestModel) do
          include Color.enum_decorator
        end,
      )

      record = DecoratedModel.create!(color: "red")
      expect(record.color).to be_red
      expect(record.color.hex).to eq "#ff0000"
      expect(DecoratedModel::COLOR::RED).to eq "red"
    end
  end
end
