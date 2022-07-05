# frozen_string_literal: true

module EnumMachine
  module AttributePersistenceMethods

    def self.[](attr, enum_values)
      Module.new do
        define_singleton_method(:extended) do |klass|
          klass.attr_accessor :parent

          klass.define_method(:inspect) do
            "#<EnumMachine:BuildAttribute value=#{self} parent=#{parent.inspect}>"
          end

          enum_values.each do |enum_value|
            enum_name = enum_value.underscore

            klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
              # def to_created!
              #   parent.update!('state' => 'created')
              # end

              def to_#{enum_name}!
                parent.update!('#{attr}' => '#{enum_value}')
              end
            RUBY
          end
        end
      end
    end

  end
end
