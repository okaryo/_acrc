# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "acrc"

class SQLiteAdapterTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("acrc-test-")
    @adapter = Acrc::SQLiteAdapter.new(File.join(@dir, "test.sqlite3"))
    @adapter.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)")
  end

  def teardown
    @adapter.close
    FileUtils.remove_entry(@dir)
  end

  def test_execute_returns_rows_with_string_column_names
    @adapter.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])

    rows = @adapter.execute("SELECT id, name FROM users")

    assert_equal [{ "id" => 1, "name" => "Alice" }], rows
  end

  def test_execute_passes_values_as_bind_parameters
    suspicious_name = "Alice' OR 1 = 1 --"
    @adapter.execute("INSERT INTO users (name) VALUES (?)", [suspicious_name])
    @adapter.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])

    rows = @adapter.execute("SELECT name FROM users WHERE name = ?", [suspicious_name])

    assert_equal [{ "name" => suspicious_name }], rows
  end

  def test_execute_wraps_sqlite_errors
    error = assert_raises(Acrc::DatabaseError) do
      @adapter.execute("SELECT * FROM missing_table")
    end

    assert_match(/missing_table/, error.message)
  end

  def test_execute_records_sql_and_binds_in_query_log
    @adapter.clear_query_log

    @adapter.execute("SELECT id FROM users WHERE name = ?", ["Alice"])

    assert_equal [{ sql: "SELECT id FROM users WHERE name = ?", binds: ["Alice"] }], @adapter.query_log
  end

  def test_clear_query_log_removes_recorded_queries
    @adapter.execute("SELECT id FROM users")

    @adapter.clear_query_log

    assert_empty @adapter.query_log
  end
end
