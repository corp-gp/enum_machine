# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe "EnumMachine without ActiveSupport" do # rubocop:disable RSpec/DescribeClass
  it "works in plain Ruby without loading ActiveSupport" do
    script = <<~RUBY
      require "enum_machine"

      raise "ActiveSupport loaded" if defined?(ActiveSupport::Inflector) || "".respond_to?(:underscore)

      COLOR = EnumMachine.enum(%w[red CartType in-delivery])
      raise "constants" unless COLOR::CART_TYPE == "CartType" && COLOR::IN_DELIVERY == "in-delivery"
      raise "predicates" unless COLOR::CART_TYPE.cart_type? && COLOR::IN_DELIVERY.in_delivery?
      raise "multi predicate" unless COLOR::RED.public_send(:red__CartType?)

      class Product
        include EnumMachine[state: { enum: %w[created approved] }]
        attr_accessor :state
      end

      product = Product.new
      product.state = "approved"
      raise "decorator" unless product.state.approved? && Product::STATE::CREATED.created?

      machine = EnumMachine::Machine.new(%w[created approved])
      machine.transitions("created" => "approved")
      raise "transitions" unless machine.transitions? && machine.possible_transitions("created") == ["approved"]

      print "ok"
    RUBY

    lib = File.expand_path("../../lib", __dir__)
    out, err, status = Open3.capture3(RbConfig.ruby, "--disable-gems", "-I", lib, "-e", script)

    expect(err).to eq("")
    expect(status).to be_success
    expect(out).to eq("ok")
  end
end
