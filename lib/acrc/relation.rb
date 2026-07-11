# frozen_string_literal: true

module Acrc
  class Relation
    include Enumerable

    attr_reader :model_class, :conditions, :orderings, :limit_value, :selected_columns, :preloads

    def initialize(model_class, conditions = [], orderings: [], limit_value: nil, selected_columns: nil, preloads: [])
      @model_class = model_class
      @conditions = conditions.freeze
      @orderings = orderings.freeze
      @limit_value = limit_value
      @selected_columns = selected_columns&.freeze
      @preloads = preloads.freeze
      @loaded = false
      @records = nil
    end

    def where(new_conditions)
      unless new_conditions.is_a?(Hash) && !new_conditions.empty?
        raise ArgumentError, "where conditions must be a non-empty hash"
      end

      spawn(conditions: conditions + normalize_conditions(new_conditions))
    end

    def order(order_conditions)
      unless order_conditions.is_a?(Hash) && !order_conditions.empty?
        raise ArgumentError, "order conditions must be a non-empty hash"
      end

      spawn(orderings: orderings + normalize_orderings(order_conditions))
    end

    def limit(value)
      integer = Integer(value)
      raise ArgumentError if integer.negative?

      spawn(limit_value: integer)
    rescue ArgumentError, TypeError
      raise ArgumentError, "limit must be a non-negative integer"
    end

    def select(*columns)
      selected = columns.flatten
      raise ArgumentError, "select columns must not be empty" if selected.empty?

      spawn(selected_columns: normalize_selected_columns(selected))
    end

    def preload(*associations)
      names = associations.flatten
      raise ArgumentError, "preload associations must not be empty" if names.empty?

      spawn(preloads: preloads + normalize_preloads(names))
    end

    def each(&block)
      to_a.each(&block)
    end

    def to_a
      @records ||= execute
      @loaded = true
      @records.dup
    end

    def loaded?
      @loaded
    end

    private

    def spawn(overrides)
      self.class.new(
        model_class,
        overrides.fetch(:conditions, conditions),
        orderings: overrides.fetch(:orderings, orderings),
        limit_value: overrides.fetch(:limit_value, limit_value),
        selected_columns: overrides.fetch(:selected_columns, selected_columns),
        preloads: overrides.fetch(:preloads, preloads)
      )
    end

    def normalize_conditions(raw_conditions)
      raw_conditions.map do |column, value|
        column_name = model_class.send(:sql_identifier, column, "column name")
        [column_name, value]
      end
    end

    def normalize_orderings(raw_orderings)
      raw_orderings.map do |column, direction|
        column_name = model_class.send(:sql_identifier, column, "column name")
        normalized_direction = direction.to_s.upcase
        unless ["ASC", "DESC"].include?(normalized_direction)
          raise ArgumentError, "order direction must be :asc or :desc"
        end

        [column_name, normalized_direction]
      end
    end

    def normalize_selected_columns(raw_columns)
      raw_columns.map do |column|
        model_class.send(:sql_identifier, column, "column name")
      end
    end

    def normalize_preloads(raw_associations)
      raw_associations.map do |association|
        association_name = association.to_s
        reflection = model_class.association_reflection(association_name)
        raise ArgumentError, "unknown association: #{association_name}" unless reflection
        raise NotImplementedError, "preload only supports belongs_to associations" unless reflection[:type] == :belongs_to

        association_name
      end
    end

    def execute
      rows = model_class.send(:execute_select, sql, binds)
      records = rows.map { |row| model_class.hydrate(row) }
      preload_records(records)
      records
    end

    def sql
      clauses = [
        "SELECT #{select_clause} FROM #{model_class.send(:sql_identifier, model_class.table_name, "table name")}"
      ]
      clauses << "WHERE #{where_clause}" unless conditions.empty?
      clauses << "ORDER BY #{order_clause}" unless orderings.empty?
      clauses << "LIMIT #{limit_value}" unless limit_value.nil?

      clauses.join(" ")
    end

    def select_clause
      return "*" unless selected_columns

      selected_columns.join(", ")
    end

    def where_clause
      conditions.map do |column, value|
        if value.is_a?(Array)
          next "1 = 0" if value.empty?

          "#{model_class.send(:sql_identifier, column, "column name")} IN (#{(["?"] * value.length).join(", ")})"
        else
          "#{model_class.send(:sql_identifier, column, "column name")} = ?"
        end
      end.join(" AND ")
    end

    def order_clause
      orderings.map do |column, direction|
        "#{model_class.send(:sql_identifier, column, "column name")} #{direction}"
      end.join(", ")
    end

    def binds
      conditions.flat_map do |condition|
        value = condition[1]
        value.is_a?(Array) ? value : [value]
      end
    end

    def preload_records(records)
      preloads.each do |association_name|
        preload_belongs_to(records, association_name)
      end
    end

    def preload_belongs_to(records, association_name)
      reflection = model_class.association_reflection(association_name)
      foreign_key = reflection[:foreign_key]
      target_class = reflection[:class_name]
      target_primary_key = target_class.primary_key
      foreign_key_values = records.map { |record| record[foreign_key] }.compact.uniq

      records.each { |record| record.send(:set_association, association_name, nil) } if foreign_key_values.empty?
      return if foreign_key_values.empty?

      target_records = target_class.where(target_primary_key => foreign_key_values).to_a
      target_records_by_key = target_records.each_with_object({}) do |target_record, by_key|
        by_key[target_record[target_primary_key]] = target_record
      end

      records.each do |record|
        foreign_key_value = record[foreign_key]
        record.send(:set_association, association_name, nil) if foreign_key_value.nil?
        record.send(:set_association, association_name, target_records_by_key[foreign_key_value]) if target_records_by_key.key?(foreign_key_value)
      end
    end
  end
end
