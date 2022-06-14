# Enum machine

Enum machine is a library for defining enums and setting state machines for attributes in ActiveRecord models and plain Ruby classes.

## Installation

Add to your Gemfile:

```ruby
gem 'enum_machine'
```

## Usage

### Enums

```ruby
# With ActiveRecord
class Product < ActiveRecord::Base
  enum_machine :color, %w(red green)
end

# Or with plain class
class Product
  include EnumMachine[color: { enum: %w[red green] }]
end

Product::COLOR.values # => ["red", "green"]
Product::COLOR::RED # => "red"
Product::COLOR::RED__GREEN # => ["red", "green"]

product = Product.new
product.color # => nil
product.color = 'red'
product.color.red? # => true
```

### Aliases

```ruby
class Product < ActiveRecord::Base
  enum_machine :state, %w[created approved published] do
    aliases(
      'forming' => %w[created approved],
    )
end

Product::STATE.forming # => %w[created approved]

product = Product.new(state: 'created')
product.state.forming? # => true
```

### Transitions

```ruby
class Product < ActiveRecord::Base
  enum_machine :color, %w[red green blue]
  enum_machine :state, %w[created approved cancelled activated] do
    transitions(
      nil                    => 'red',
      'created'              => [nil, 'approved'],
      %w[cancelled approved] => 'activated',
      'activated'            => %w[created cancelled],
    )

    # Will be executed in `after_validation` callback
    # Errors added here will prevent record to be saved and `after_transition` blocks to be executed
    before_transition 'created' => 'approved' do |product|
      product.errors.add(:state, :invalid, message: 'invalid transition') if product.color.red?
    end

    # Will be executed in `after_save` callback
    after_transition %w[created] => %w[approved] do |product|
      product.color = 'red'
    end

    after_transition any => 'cancelled' do |product|
      product.cancelled_at = Time.zone.now
    end
  end
end

product = Product.create(state: 'created')
product.state.possible_transitions # => [nil, "approved"]
product.state.can_activated? # => false
product.state.to_activated! # => EnumMachine::Error: transition "created" => "activated" not defined in enum_machine
product.state.to_approved! # => true; equal to `product.update!(state: 'approved')`
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
  enum_machine :color, %w(red green)
end

# Plain class
class Product
  # `i18n_scope` option must be explicitly set to use methods below
  include EnumMachine[color: { enum: %w[red green], i18n_scope: 'product' }]
end

Product::COLOR.human_name_for('red') # => 'Красный'
Product::COLOR.values_for_form # => [["Красный", "red"], ["Зеленый", "green"]]

product = Product.new(color: 'red')
product.color.human_name # => 'Красный'
```

I18n scope can be changed with `i18n_scope` option:

```ruby
# For AciveRecord
class Product < ActiveRecord::Base
  enum_machine :color, %w(red green), i18n_scope: 'users.product'
end

# For plain class
class Product
  include EnumMachine[color: { enum: %w[red green], i18n_scope: 'users.product' }]
end
```

**ru.yml**
```yml
ru:
  enums:
    users:
      product:
        color:
          red: Красный
          green: Зеленый
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
