# frozen_string_literal: true

require "sqlite3"

module Acrc
  class SQLiteAdapter
    def initialize(path)
      @database = SQLite3::Database.new(path)
      @database.results_as_hash = true
      @query_log = []
      @transaction_depth = 0
    end

    attr_reader :query_log

    def execute(sql, binds = [])
      query_log << { sql: sql, binds: binds.dup }
      database.execute(sql, binds).map { |row| normalize_row(row) }
    rescue SQLite3::ConstraintException => e
      raise ConstraintError, e.message
    rescue SQLite3::Exception => e
      raise DatabaseError, e.message
    end

    def clear_query_log
      query_log.clear
    end

    def transaction
      raise ArgumentError, "transaction requires a block" unless block_given?

      if transaction_open?
        transaction_with_savepoint { yield }
      else
        transaction_with_begin { yield }
      end
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

    def transaction_open?
      @transaction_depth.positive?
    end

    def transaction_with_begin
      @transaction_depth += 1
      execute("BEGIN")
      result = yield
      execute("COMMIT")
      result
    rescue StandardError
      execute("ROLLBACK") if transaction_open?
      raise
    ensure
      @transaction_depth -= 1
    end

    def transaction_with_savepoint
      savepoint_name = "acrc_savepoint_#{@transaction_depth + 1}"
      @transaction_depth += 1
      execute("SAVEPOINT #{savepoint_name}")
      result = yield
      execute("RELEASE SAVEPOINT #{savepoint_name}")
      result
    rescue StandardError
      execute("ROLLBACK TO SAVEPOINT #{savepoint_name}")
      execute("RELEASE SAVEPOINT #{savepoint_name}")
      raise
    ensure
      @transaction_depth -= 1
    end

    def normalize_row(row)
      row.each_with_object({}) do |(key, value), normalized|
        normalized[key] = value if key.is_a?(String)
      end
    end
  end
end
