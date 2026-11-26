# frozen_string_literal: true

module EnumMachine
  # Minimal replacements for ActiveSupport string inflections, so the gem works without Rails.
  # Delegates to ActiveSupport::Inflector when it is loaded, so acronym inflections
  # configured in a Rails app are respected.
  #
  # Adapted from ActiveSupport::Inflector (activesupport 8.1.4.1, MIT License,
  # Copyright (c) David Heinemeier Hansson), lib/active_support/inflector/methods.rb
  module Inflector
    module_function

    def underscore(camel_cased_word)
      return ActiveSupport::Inflector.underscore(camel_cased_word) if defined?(ActiveSupport::Inflector.underscore)

      return camel_cased_word.to_s.dup unless /[A-Z-]|::/.match?(camel_cased_word)

      word = camel_cased_word.to_s.gsub("::", "/")
      # ActiveSupport applies `inflections.acronyms_underscore_regex` here;
      # without configured acronyms it never matches, so it is omitted.
      word.gsub!(/(?<=[A-Z])(?=[A-Z][a-z])|(?<=[a-z\d])(?=[A-Z])/, "_")
      word.tr!("-", "_")
      word.downcase!
      word
    end

    def demodulize(path)
      path = path.to_s
      if (i = path.rindex("::"))
        path[(i + 2), path.length]
      else
        path
      end
    end
  end
end
