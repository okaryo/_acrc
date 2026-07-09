# frozen_string_literal: true

module Acrc
  class Relation
    include Enumerable

    attr_reader :model_class, :conditions

    def initialize(model_class, conditions = [])
      @model_class = model_class
      @conditions = conditions.freeze
      @loaded = false
      @records = nil
    end

    def where(new_conditions)
      unless new_conditions.is_a?(Hash) && !new_conditions.empty?
        raise ArgumentError, "where conditions must be a non-empty hash"
      end

      self.class.new(model_class, conditions + normalize_conditions(new_conditions))
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

    def normalize_conditions(raw_conditions)
      raw_conditions.map do |column, value|
        column_name = model_class.send(:sql_identifier, column, "column name")
        [column_name, value]
      end
    end

    def execute
      rows = model_class.send(:execute_select, sql, binds)
      rows.map { |row| model_class.hydrate(row) }
    end

    def sql
      base = "SELECT * FROM #{model_class.send(:sql_identifier, model_class.table_name, "table name")}"
      return base if conditions.empty?

      "#{base} WHERE #{where_clause}"
    end

    def where_clause
      conditions.map do |column, _value|
        "#{model_class.send(:sql_identifier, column, "column name")} = ?"
      end.join(" AND ")
    end

    def binds
      conditions.map { |_column, value| value }
    end
  end
end
