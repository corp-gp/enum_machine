# Переход с `rails_string_enum` на `enum_machine`

### 1. Объявление в классе
```ruby
class Product
  string_enum :color, %w[red green] # Было
  enum_machine :color, %w[red green] # Стало
end
```

### 2. Константы

Все константы находятся в Product::COLOR

* `Product::RED` => `Product::COLOR::RED`
* `Product::RED__GREEN` => `Product::COLOR::RED__GREEN`
* `Product::COLORS` => `Product::COLOR.values`

### 3. Методы инстанса

* `@product.red?` => `@product.color.red?`

### 4. I18n хелперы

* `Product.colors_i18n` => `Product::COLOR.values_for_form`
* `Product.color_i18n_for('red')` => `Product::COLOR.human_name_for('red')`
* `@product.color_i18n` => `@product.color.human_name`

### 5. scopes

В `enum_machine` нет опции `scopes`, нужно задать необходимые вручную

```ruby
class Product
  # Было
  string_enum :color, %w[red green], scopes: true

  # Стало
  enum_machine :color, %w[red green]
  scope :only_red, -> { where(color: COLOR::RED) }
end
```

### 6. Интеграция с `simple_form`

`enum_machine` не предоставляет интеграцию с `simple_form`, тип инпута и коллекцию нужно передавать самостоятельно

```ruby
# Было
f.input :color

# Стало
f.input :color, as: :select, collection: Product::COLOR.values_for_form
```
