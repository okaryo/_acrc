# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "acrc"

class MigrationTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("acrc-test-")
    @adapter = Acrc::SQLiteAdapter.new(File.join(@dir, "test.sqlite3"))
    @runner = Acrc::MigrationRunner.new(@adapter)
  end

  def teardown
    @adapter.close
    FileUtils.remove_entry(@dir)
  end

  def test_migration_requires_a_version
    error = assert_raises(ArgumentError) do
      Acrc::Migration.new("") { |db| db.execute("SELECT 1") }
    end

    assert_equal "migration version must not be empty", error.message
  end

  def test_migration_requires_a_block
    error = assert_raises(ArgumentError) do
      Acrc::Migration.new("202607120001")
    end

    assert_equal "migration requires a block", error.message
  end

  def test_migrate_runs_pending_migrations_in_version_order
    migrations = [
      Acrc::Migration.new("202607120002", "add_age") do |db|
        db.execute("ALTER TABLE users ADD COLUMN age INTEGER")
      end,
      Acrc::Migration.new("202607120001", "create_users") do |db|
        db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
      end
    ]

    applied = @runner.migrate(migrations)

    assert_equal ["202607120001", "202607120002"], applied
    assert_equal ["id", "name", "age"], @adapter.columns("users").map(&:name)
    assert_equal ["202607120001", "202607120002"], @runner.applied_versions
  end

  def test_migrate_skips_already_applied_versions
    migration = Acrc::Migration.new("202607120001", "create_users") do |db|
      db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    end

    assert_equal ["202607120001"], @runner.migrate([migration])
    assert_equal [], @runner.migrate([migration])
    assert_equal ["202607120001"], @runner.applied_versions
  end

  def test_failed_migration_rolls_back_schema_and_version_record
    migration = Acrc::Migration.new("202607120001", "create_then_fail") do |db|
      db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
      raise "boom"
    end

    error = assert_raises(RuntimeError) do
      @runner.migrate([migration])
    end

    assert_equal "boom", error.message
    assert_equal [], @runner.applied_versions
    assert_equal [], @adapter.columns("users")
  end
end
