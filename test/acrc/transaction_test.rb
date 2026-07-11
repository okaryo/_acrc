# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "acrc"

class TransactionTest < Minitest::Test
  class User < Acrc::Model
    table_name "users"
    attribute :id, :integer
  end

  def setup
    @dir = Dir.mktmpdir("acrc-test-")
    @adapter = Acrc::SQLiteAdapter.new(File.join(@dir, "test.sqlite3"))
    @adapter.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)")
    User.connection @adapter
  end

  def teardown
    @adapter.close
    FileUtils.remove_entry(@dir)
  end

  def test_transaction_commits_successful_work
    User.transaction do
      User.new("name" => "Alice").save
      User.new("name" => "Bob").save
    end

    assert_equal ["Alice", "Bob"], User.all.order(id: :asc).map(&:name)
  end

  def test_transaction_rolls_back_when_the_block_raises
    error = assert_raises(RuntimeError) do
      User.transaction do
        User.new("name" => "Alice").save
        raise "boom"
      end
    end

    assert_equal "boom", error.message
    assert_empty User.all.to_a
  end

  def test_transaction_rolls_back_when_a_constraint_error_is_raised
    error = assert_raises(Acrc::ConstraintError) do
      User.transaction do
        User.new("name" => "Alice").save
        User.new("name" => nil).save
      end
    end

    assert_match(/NOT NULL constraint failed/, error.message)
    assert_empty User.all.to_a
  end

  def test_transaction_returns_the_block_value
    result = User.transaction do
      User.new("name" => "Alice").save
      "created"
    end

    assert_equal "created", result
  end

  def test_transaction_records_begin_commit_and_rollback_in_query_log
    @adapter.clear_query_log

    User.transaction { User.new("name" => "Alice").save }
    assert_equal ["BEGIN", "INSERT INTO users (name) VALUES (?)", "COMMIT"], @adapter.query_log.map { |entry| entry[:sql] }

    @adapter.clear_query_log
    assert_raises(RuntimeError) do
      User.transaction do
        User.new("name" => "Bob").save
        raise "boom"
      end
    end

    assert_equal ["BEGIN", "INSERT INTO users (name) VALUES (?)", "ROLLBACK"], @adapter.query_log.map { |entry| entry[:sql] }
  end

  def test_nested_transactions_use_savepoints
    User.transaction do
      User.new("name" => "Alice").save
      User.transaction { User.new("name" => "Bob").save }
    end

    assert_equal ["Alice", "Bob"], User.all.order(id: :asc).map(&:name)
  end

  def test_nested_transaction_can_roll_back_to_savepoint_and_continue_outer_transaction
    User.transaction do
      User.new("name" => "Alice").save

      begin
        User.transaction do
          User.new("name" => "Bob").save
          raise "rollback inner"
        end
      rescue RuntimeError
        User.new("name" => "Carol").save
      end
    end

    assert_equal ["Alice", "Carol"], User.all.order(id: :asc).map(&:name)
  end

  def test_uncaught_nested_transaction_error_rolls_back_the_outer_transaction
    error = assert_raises(RuntimeError) do
      User.transaction do
        User.new("name" => "Alice").save
        User.transaction do
          User.new("name" => "Bob").save
          raise "rollback all"
        end
      end
    end

    assert_equal "rollback all", error.message
    assert_empty User.all.to_a
  end

  def test_nested_transactions_record_savepoint_sql
    @adapter.clear_query_log

    User.transaction do
      User.new("name" => "Alice").save
      User.transaction { User.new("name" => "Bob").save }
    end

    assert_equal(
      [
        "BEGIN",
        "INSERT INTO users (name) VALUES (?)",
        "SAVEPOINT acrc_savepoint_2",
        "INSERT INTO users (name) VALUES (?)",
        "RELEASE SAVEPOINT acrc_savepoint_2",
        "COMMIT"
      ],
      @adapter.query_log.map { |entry| entry[:sql] }
    )
  end

  def test_transaction_requires_a_connection
    disconnected_model = Class.new(Acrc::Model) do
      table_name "users"
    end

    error = assert_raises(Acrc::ConfigurationError) do
      disconnected_model.transaction {}
    end

    assert_equal "model connection is not configured", error.message
  end
end
