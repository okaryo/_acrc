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
end
