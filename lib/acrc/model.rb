# frozen_string_literal: true

require "time"

module Acrc
  class Model
    SUPPORTED_ATTRIBUTE_TYPES = [:integer, :float, :string, :boolean, :time].freeze

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

    def self.attribute(name, type)
      type = type.to_sym
      unless SUPPORTED_ATTRIBUTE_TYPES.include?(type)
        raise UnknownTypeError, "unknown attribute type: #{type.inspect}"
      end

      local_attribute_types[name.to_s] = type
    end

    def self.attribute_types
      parent_types =
        if superclass.respond_to?(:attribute_types)
          superclass.attribute_types
        else
          {}
        end

      parent_types.merge(local_attribute_types)
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
      new(attributes, persisted: true)
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

    def self.local_attribute_types
      @attribute_types ||= {}
    end
    private_class_method :local_attribute_types

    def self.type_cast_attributes(attributes)
      attributes.each_with_object({}) do |(name, value), casted|
        casted[name] = type_cast_value(name, value)
      end
    end
    private_class_method :type_cast_attributes

    def self.type_cast_value(name, value)
      type = attribute_types[name]
      return value unless type
      return nil if value.nil?

      case type
      when :integer
        Integer(value)
      when :float
        Float(value)
      when :string
        value.to_s
      when :boolean
        type_cast_boolean(name, value)
      when :time
        value.is_a?(Time) ? value : Time.parse(value.to_s)
      else
        value
      end
    rescue ArgumentError, TypeError
      raise TypeCastError, "could not cast #{name} to #{type}: #{value.inspect}"
    end
    private_class_method :type_cast_value

    def self.type_cast_boolean(name, value)
      return value if value == true || value == false
      return true if [1, "1", "true", "t", "yes"].include?(value)
      return false if [0, "0", "false", "f", "no"].include?(value)

      raise TypeCastError, "could not cast #{name} to boolean: #{value.inspect}"
    end
    private_class_method :type_cast_boolean

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

    def initialize(attributes = {}, options = {})
      persisted = options.fetch(:persisted, false)
      @attributes = self.class.send(:type_cast_attributes, self.class.send(:stringify_keys, attributes))
      @original_attributes = persisted ? @attributes.dup : {}
      @new_record = !persisted
      define_attribute_readers
    end

    def save
      raise NotImplementedError, "updating existing records is not implemented yet" unless new_record?

      insert
      true
    end

    def new_record?
      @new_record
    end

    def persisted?
      !new_record?
    end

    def [](name)
      key = name.to_s
      return attributes[key] if attributes.key?(key)

      raise UnknownAttributeError, "unknown attribute: #{key}"
    end

    def attributes
      @attributes.dup
    end

    def original_attributes
      @original_attributes.dup
    end

    private

    def insert
      adapter = self.class.connection
      raise ConfigurationError, "#{self.class.send(:model_name)} connection is not configured" unless adapter

      insert_attributes = attributes_for_insert
      if insert_attributes.empty?
        adapter.execute("INSERT INTO #{table_identifier} DEFAULT VALUES")
      else
        columns = insert_attributes.keys.map { |name| self.class.send(:sql_identifier, name, "column name") }
        placeholders = (["?"] * columns.length).join(", ")
        adapter.execute(
          "INSERT INTO #{table_identifier} (#{columns.join(", ")}) VALUES (#{placeholders})",
          insert_attributes.values
        )
      end

      store_generated_primary_key(adapter)
      mark_persisted
    end

    def attributes_for_insert
      primary_key = self.class.primary_key
      @attributes.reject { |name, value| name == primary_key && value.nil? }
    end

    def table_identifier
      self.class.send(:sql_identifier, self.class.table_name, "table name")
    end

    def store_generated_primary_key(adapter)
      primary_key = self.class.primary_key
      return if @attributes.key?(primary_key) && !@attributes[primary_key].nil?
      return unless adapter.respond_to?(:last_insert_row_id)

      @attributes[primary_key] = self.class.send(:type_cast_value, primary_key, adapter.last_insert_row_id)
      define_attribute_readers
    end

    def mark_persisted
      @new_record = false
      @original_attributes = @attributes.dup
    end

    def define_attribute_readers
      @attributes.each_key do |name|
        next unless self.class.send(:safe_reader_name?, name)
        next if respond_to?(name)

        define_singleton_method(name) { self[name] }
      end
    end
  end
end
