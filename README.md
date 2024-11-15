# Enum machine

Enum machine is a library for defining enums and setting state machines for attributes in ActiveRecord models and plain Ruby classes.

You can visualize transitions map with [enum_machine-contrib](https://github.com/corp-gp/enum_machine-contrib)

## Why is `enum_machine` better then [state_machines](https://github.com/state-machines/state_machines) / [aasm](https://github.com/aasm/aasm)?

- faster [5x](#Benchmarks)
- code lines: `enum_machine` - 348, `AASM` - 2139
- namespaced (via attr) by default: `order.state.to_collected`
- [aliases](Aliases)
- guarantees of existing transitions
- simple run transitions with callbacks `order.update(state: "collected")` or `order.state.to_collected`
- `aasm` / `state_machines` **event driven**, `enum_machine` **state driven**

```ruby
# aasm
event :complete do # complete/collected - dichotomy between states and events
  before { puts "event complete" }
  transitions from: :collecting, to: :collected
end

# pay/archived difficult to remember the relationship between statuses and events
# try to explain this to the logic of business stakeholders
event :pay do
  transitions from: [:created, :collected], to: :archived
end

order = Order.create(state: "collecting")
order.update(state: "archived") # not check transitions, invalid logic
order.update(state: "collected") # not run callbacks 
order.complete # need use event for transition, but your object in UI and DB have only states

# enum_machine
transitions( # simple readable transitions map
  "collecting" => "collected",
  "collected"  => "archived",
)
before_transition("collecting" => "collected") { puts "event complete" }

order = Order.create(state: "collecting")
order.update(state: "archived") # checked transitions, raise exception
order.update(state: "collected") # run callbacks
```

## Installation

Add to your Gemfile:

```ruby
gem "enum_machine"
```

## Usage

### Enums

```ruby
# With ActiveRecord
class Product < ActiveRecord::Base
  enum_machine :color, %w[red green]
end

# Or with plain class
class Product
  # attributes must be defined before including the EnumMachine module
  attr_accessor :color
  
  include EnumMachine[color: { enum: %w[red green] }]
  # or reuse from model
  Product::COLOR.decorator_module
end

Product::COLOR.values # => ["red", "green"]
Product::COLOR::RED # => "red"
Product::COLOR::RED__GREEN # => ["red", "green"]

product = Product.new
product.color # => nil
product.color = "red"
product.color.red? # => true
product.color.human_name # => "Красный"
```

### Aliases

```ruby
class Product < ActiveRecord::Base
  enum_machine :state, %w[created approved published] do
    aliases(
      "forming" => %w[created approved],
    )
  end
end

Product::STATE.forming # => %w[created approved]

product = Product.new(state: "created")
product.state.forming? # => true
```

### Transitions

```ruby
class Product < ActiveRecord::Base
  enum_machine :color, %w[red green blue]
  enum_machine :state, %w[created approved cancelled activated] do
    # transitions(any => any) - allow all transitions
    transitions(
      nil                    => "created",
      "created"              => [nil, "approved"],
      %w[cancelled approved] => "activated",
      "activated"            => %w[created cancelled],
    )

    # Will be executed in `before_save` callback
    before_transition "created" => "approved" do |product|
      product.color = "green" if product.color.red?
    end

    # Will be executed in `after_save` callback
    after_transition %w[created] => %w[approved] do |product|
      product.color = "red"
    end

    after_transition any => "cancelled" do |product|
      product.cancelled_at = Time.zone.now
    end
  end
end

product = Product.create(state: "created")
product.state.possible_transitions # => [nil, "approved"]
product.state.can_activated? # => false
product.state.to_activated! # => EnumMachine::Error: transition "created" => "activated" not defined in enum_machine
product.state.to_approved! # => true; equal to `product.update!(state: "approve")`
```

#### Skip transitions
```ruby
product = Product.new(state: "created")
product.skip_state_transitions { product.save }
```

method generated as `skip_#{enum_name}_transitions`

#### Skip in factories
```ruby
FactoryBot.define do
  factory :product do
    name { Faker::Commerce.product_name }
    to_create { |product| product.skip_state_transitions { product.save! } }
  end
end
```

### I18n

**ru.yml**
```yml
ru:
  enums:
    product:
      color:
        red: Красный
        green: Зеленый
```

```ruby
# ActiveRecord
class Product < ActiveRecord::Base
  enum_machine :color, %w[red green]
end

# Plain class
class Product
  # attributes must be defined before including the EnumMachine module
  attr_accessor :color
  # `i18n_scope` option must be explicitly set to use methods below
  include EnumMachine[color: { enum: %w[red green], i18n_scope: "product" }]
end

Product::COLOR.human_name_for("red") # => "Красный"
Product::COLOR.values_for_form # => [["Красный", "red"], ["Зеленый", "green"]]

product = Product.new(color: "red")
product.color.human_name # => "Красный"
```

I18n scope can be changed with `i18n_scope` option:

```ruby
# For AciveRecord
class Product < ActiveRecord::Base
  enum_machine :color, %w[red green], i18n_scope: "users.product"
end

# For plain class
class Product
  include EnumMachine[color: { enum: %w[red green], i18n_scope: "users.product" }]
end
```

## Benchmarks
[test/performance.rb](../master/test/performance.rb)

| Gem            | Method                                                            |                                |
| :---           |                                                              ---: | :---                           |
| enum_machine   | order.state.forming?                                              |  894921.3 i/s                  |
| state_machines | order.forming?                                                    |  189901.8 i/s - 4.71x  slower  |
| aasm           | order.forming?                                                    |  127073.7 i/s - 7.04x  slower  |
|                |                                                                   |                                |
| enum_machine   | order.state.can_closed?                                           |  473150.4 i/s                  |
| aasm           | order.may_to_closed?                                              |   24459.1 i/s - 19.34x  slower |
| state_machines | order.can_to_closed?                                              |   12136.8 i/s - 38.98x  slower |
|                |                                                                   |                                |
| enum_machine   | Order::STATE.values                                               | 6353820.4 i/s                  |
| aasm           | Order.aasm(:state).states.map(&:name)                             |  131390.5 i/s - 48.36x  slower |
| state_machines | Order.state_machines[:state].states.map(&:value)                  |  108449.7 i/s - 58.59x  slower |
|                |                                                                   |                                |
| enum_machine   | order.state = "forming" and order.valid?                          |   13873.4 i/s                  |
| state_machines | order.state_event = "to_forming" and order.valid?                 |   6173.6 i/s - 2.25x  slower   |
| aasm           | order.to_forming                                                  |   3095.9 i/s - 4.48x  slower   |


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
