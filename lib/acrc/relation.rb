# frozen_string_literal: true

module Acrc
  class Relation
    include Enumerable

    attr_reader :model_class, :conditions, :orderings, :limit_value, :selected_columns

    def initialize(model_class, conditions = [], orderings: [], limit_value: nil, selected_columns: nil)
      @model_class = model_class
      @conditions = conditions.freeze
      @orderings = orderings.freeze
      @limit_value = limit_value
      @selected_columns = selected_columns&.freeze
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
        selected_columns: overrides.fetch(:selected_columns, selected_columns)
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

    def execute
      rows = model_class.send(:execute_select, sql, binds)
      rows.map { |row| model_class.hydrate(row) }
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
      conditions.map do |column, _value|
        "#{model_class.send(:sql_identifier, column, "column name")} = ?"
      end.join(" AND ")
    end

    def order_clause
      orderings.map do |column, direction|
        "#{model_class.send(:sql_identifier, column, "column name")} #{direction}"
      end.join(", ")
    end

    def binds
      conditions.map { |_column, value| value }
    end
  end
end
