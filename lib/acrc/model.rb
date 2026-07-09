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

    def self.connection(adapter = nil)
      @connection = adapter if adapter
      @connection
    end

    def self.find(id)
      row = execute_select(
        "SELECT * FROM #{sql_identifier(table_name, "table name")} " \
        "WHERE #{sql_identifier(primary_key, "primary key")} = ? LIMIT 1",
        [id]
      ).first

      return hydrate(row) if row

      raise RecordNotFound, "could not find #{model_name} with #{primary_key}=#{id.inspect}"
    end

    def self.where(conditions)
      unless conditions.is_a?(Hash) && !conditions.empty?
        raise ArgumentError, "where conditions must be a non-empty hash"
      end

      clauses = []
      binds = []

      conditions.each do |column, value|
        clauses << "#{sql_identifier(column, "column name")} = ?"
        binds << value
      end

      execute_select(
        "SELECT * FROM #{sql_identifier(table_name, "table name")} " \
        "WHERE #{clauses.join(" AND ")}",
        binds
      ).map { |row| hydrate(row) }
    end

    def self.hydrate(row)
      attributes = stringify_keys(row)
      new(attributes)
    end

    def self.execute_select(sql, binds)
      adapter = connection
      raise ConfigurationError, "#{model_name} connection is not configured" unless adapter

      adapter.execute(sql, binds)
    end
    private_class_method :execute_select

    def self.sql_identifier(value, label)
      identifier = value.to_s
      raise ConfigurationError, "#{model_name} #{label} is not configured" if identifier.empty?

      return identifier if /\A[a-zA-Z_][a-zA-Z0-9_]*\z/.match?(identifier)

      raise InvalidIdentifierError, "invalid #{label}: #{identifier.inspect}"
    end
    private_class_method :sql_identifier

    def self.model_name
      name || "model"
    end
    private_class_method :model_name

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
