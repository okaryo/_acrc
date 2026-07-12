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

    def self.transaction(&block)
      adapter = connection
      raise ConfigurationError, "#{model_name} connection is not configured" unless adapter

      adapter.transaction(&block)
    end

    def self.columns
      adapter = connection
      raise ConfigurationError, "#{model_name} connection is not configured" unless adapter

      adapter.columns(table_name)
    end

    def self.column_names
      columns.map(&:name)
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

    def self.validates_presence_of(*names)
      names.each do |name|
        local_validations << { type: :presence, name: name.to_s }
      end
    end

    def self.validations
      parent_validations =
        if superclass.respond_to?(:validations)
          superclass.validations
        else
          []
        end

      parent_validations + local_validations
    end

    def self.find(id)
      record = where(primary_key => id).to_a.first

      return record if record

      raise RecordNotFound, "could not find #{model_name} with #{primary_key}=#{id.inspect}"
    end

    def self.where(conditions)
      all.where(conditions)
    end

    def self.select(*columns)
      all.select(*columns)
    end

    def self.preload(*associations)
      all.preload(*associations)
    end

    def self.all
      Relation.new(self)
    end

    def self.belongs_to(name, class_name:, foreign_key:)
      association_name = name.to_s
      foreign_key_name = foreign_key.to_s
      association_reflections[association_name] = {
        type: :belongs_to,
        class_name: class_name,
        foreign_key: foreign_key_name
      }

      define_method(association_name) do
        return @association_cache[association_name] if @association_cache.key?(association_name)

        foreign_key_value = self[foreign_key_name]
        return nil if foreign_key_value.nil?

        class_name.find(foreign_key_value)
      end
    end

    def self.has_many(name, class_name:, foreign_key:)
      association_name = name.to_s
      foreign_key_name = foreign_key.to_s
      association_reflections[association_name] = {
        type: :has_many,
        class_name: class_name,
        foreign_key: foreign_key_name
      }

      define_method(association_name) do
        class_name.where(foreign_key_name => self[self.class.primary_key])
      end
    end

    def self.association_reflection(name)
      association_reflections[name.to_s]
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

    def self.local_validations
      @validations ||= []
    end
    private_class_method :local_validations

    def self.association_reflections
      @association_reflections ||= {}
    end
    private_class_method :association_reflections

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
      @destroyed = false
      @association_cache = {}
      @errors = {}
      define_attribute_methods
    end

    def save
      raise DestroyedRecordError, "cannot save a destroyed record" if destroyed?
      return false unless valid?

      if new_record?
        insert
      else
        update
      end
      true
    end

    def new_record?
      @new_record
    end

    def persisted?
      !new_record? && !destroyed?
    end

    def destroyed?
      @destroyed
    end

    def valid?
      @errors = {}
      run_validations
      @errors.empty?
    end

    def errors
      @errors.transform_values(&:dup)
    end

    def destroy
      delete
      mark_destroyed
      self
    end

    def [](name)
      key = name.to_s
      return attributes[key] if attributes.key?(key)

      raise UnknownAttributeError, "unknown attribute: #{key}"
    end

    def []=(name, value)
      key = name.to_s
      @attributes[key] = self.class.send(:type_cast_value, key, value)
      define_attribute_methods
    end

    def attributes
      @attributes.dup
    end

    def original_attributes
      @original_attributes.dup
    end

    def changed?
      !changes.empty?
    end

    def changes
      changed_attribute_names.each_with_object({}) do |name, changed|
        changed[name] = [@original_attributes[name], @attributes[name]]
      end
    end

    private

    def set_association(name, value)
      @association_cache[name.to_s] = value
    end

    def run_validations
      self.class.validations.each do |validation|
        case validation[:type]
        when :presence
          validate_presence(validation[:name])
        end
      end
    end

    def validate_presence(name)
      value = @attributes[name]
      return unless value.nil? || (value.respond_to?(:empty?) && value.empty?)

      add_error(name, "can't be blank")
    end

    def add_error(name, message)
      @errors[name] ||= []
      @errors[name] << message
    end

    def delete
      return if new_record?

      adapter = self.class.connection
      raise ConfigurationError, "#{self.class.send(:model_name)} connection is not configured" unless adapter

      primary_key = self.class.primary_key
      primary_key_value = @attributes[primary_key]
      raise UnknownAttributeError, "unknown attribute: #{primary_key}" if primary_key_value.nil?

      adapter.execute(
        "DELETE FROM #{table_identifier} " \
        "WHERE #{self.class.send(:sql_identifier, primary_key, "primary key")} = ?",
        [primary_key_value]
      )
      ensure_row_was_changed(adapter)
    end

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

    def update
      adapter = self.class.connection
      raise ConfigurationError, "#{self.class.send(:model_name)} connection is not configured" unless adapter

      update_attributes = attributes_for_update
      return if update_attributes.empty?

      primary_key = self.class.primary_key
      primary_key_value = @attributes[primary_key]
      raise UnknownAttributeError, "unknown attribute: #{primary_key}" if primary_key_value.nil?

      assignments = update_attributes.keys.map do |name|
        "#{self.class.send(:sql_identifier, name, "column name")} = ?"
      end

      adapter.execute(
        "UPDATE #{table_identifier} SET #{assignments.join(", ")} " \
        "WHERE #{self.class.send(:sql_identifier, primary_key, "primary key")} = ?",
        update_attributes.values + [primary_key_value]
      )
      ensure_row_was_changed(adapter)
      mark_persisted
    end

    def attributes_for_insert
      primary_key = self.class.primary_key
      @attributes.reject { |name, value| name == primary_key && value.nil? }
    end

    def attributes_for_update
      primary_key = self.class.primary_key
      changed_attribute_names.each_with_object({}) do |name, values|
        values[name] = @attributes[name] unless name == primary_key
      end
    end

    def changed_attribute_names
      @attributes.keys.select { |name| @original_attributes[name] != @attributes[name] }
    end

    def table_identifier
      self.class.send(:sql_identifier, self.class.table_name, "table name")
    end

    def store_generated_primary_key(adapter)
      primary_key = self.class.primary_key
      return if @attributes.key?(primary_key) && !@attributes[primary_key].nil?
      return unless adapter.respond_to?(:last_insert_row_id)

      @attributes[primary_key] = self.class.send(:type_cast_value, primary_key, adapter.last_insert_row_id)
      define_attribute_methods
    end

    def ensure_row_was_changed(adapter)
      return unless adapter.respond_to?(:changes)
      return unless adapter.changes.zero?

      raise StaleRecordError, "attempted to update or delete a stale #{self.class.send(:model_name)}"
    end

    def mark_persisted
      @new_record = false
      @destroyed = false
      @original_attributes = @attributes.dup
    end

    def mark_destroyed
      @new_record = false
      @destroyed = true
      @original_attributes = @attributes.dup
    end

    def define_attribute_methods
      @attributes.each_key do |name|
        next unless self.class.send(:safe_reader_name?, name)

        define_singleton_method(name) { self[name] } unless respond_to?(name)

        writer_name = "#{name}="
        define_singleton_method(writer_name) { |value| self[name] = value } unless respond_to?(writer_name)
      end
    end
  end
end
