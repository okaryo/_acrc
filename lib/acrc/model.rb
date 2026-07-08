# frozen_string_literal: true

module Acrc
  class Model
    def self.table_name(value = nil)
      @table_name = value.to_s if value
      @table_name
    end

    def self.primary_key(value = nil)
      @primary_key = value.to_s if value
      @primary_key || "id"
    end

    def self.hydrate(row)
      attributes = stringify_keys(row)
      new(attributes)
    end

    def self.stringify_keys(row)
      row.each_with_object({}) do |(key, value), attributes|
        attributes[key.to_s] = value
      end
    end
    private_class_method :stringify_keys

    def self.safe_reader_name?(name)
      /\A[a-z_]\w*\z/.match?(name)
    end
    private_class_method :safe_reader_name?

    def initialize(attributes)
      @attributes = self.class.send(:stringify_keys, attributes)
      define_attribute_readers
    end

    def [](name)
      key = name.to_s
      return attributes[key] if attributes.key?(key)

      raise UnknownAttributeError, "unknown attribute: #{key}"
    end

    def attributes
      @attributes.dup
    end

    private

    def define_attribute_readers
      @attributes.each_key do |name|
        next unless self.class.send(:safe_reader_name?, name)
        next if respond_to?(name)

        define_singleton_method(name) { self[name] }
      end
    end
  end
end
