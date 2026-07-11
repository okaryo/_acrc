# frozen_string_literal: true

require "sqlite3"

module Acrc
  class SQLiteAdapter
    def initialize(path)
      @database = SQLite3::Database.new(path)
      @database.results_as_hash = true
      @query_log = []
    end

    attr_reader :query_log

    def execute(sql, binds = [])
      query_log << { sql: sql, binds: binds.dup }
      database.execute(sql, binds).map { |row| normalize_row(row) }
    rescue SQLite3::Exception => e
      raise DatabaseError, e.message
    end

    def clear_query_log
      query_log.clear
    end

    def last_insert_row_id
      database.last_insert_row_id
    end

    def changes
      database.changes
    end

    def close
      database.close unless database.closed?
    end

    private

    attr_reader :database

    def normalize_row(row)
      row.each_with_object({}) do |(key, value), normalized|
        normalized[key] = value if key.is_a?(String)
      end
    end
  end
end
