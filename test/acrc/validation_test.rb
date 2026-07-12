# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "acrc"

class ValidationTest < Minitest::Test
  class User < Acrc::Model
    table_name "users"
    attribute :id, :integer
    validates_presence_of :name
  end

  class Admin < User
    validates_presence_of :role
  end

  def setup
    @dir = Dir.mktmpdir("acrc-test-")
    @adapter = Acrc::SQLiteAdapter.new(File.join(@dir, "test.sqlite3"))
    @adapter.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, role TEXT)")
    User.connection @adapter
    Admin.connection @adapter
  end

  def teardown
    @adapter.close
    FileUtils.remove_entry(@dir)
  end

  def test_valid_returns_true_when_presence_validation_passes
    user = User.new("name" => "Alice")

    assert user.valid?
    assert_equal({}, user.errors)
  end

  def test_valid_returns_false_and_records_errors_when_presence_validation_fails
    user = User.new("name" => nil)

    refute user.valid?
    assert_equal({ "name" => ["can't be blank"] }, user.errors)
  end

  def test_presence_validation_treats_empty_strings_as_blank
    user = User.new("name" => "")

    refute user.valid?
    assert_equal({ "name" => ["can't be blank"] }, user.errors)
  end

  def test_save_returns_false_and_does_not_insert_when_validation_fails
    user = User.new("name" => nil)
    @adapter.clear_query_log

    assert_equal false, user.save

    assert user.new_record?
    refute user.persisted?
    assert_equal({ "name" => ["can't be blank"] }, user.errors)
    assert_empty @adapter.execute("SELECT * FROM users")
    refute_includes @adapter.query_log.map { |entry| entry[:sql] }, "INSERT INTO users (name) VALUES (?)"
  end

  def test_save_clears_previous_validation_errors_after_success
    user = User.new("name" => nil)

    assert_equal false, user.save
    user.name = "Alice"

    assert_equal true, user.save
    assert_equal({}, user.errors)
    assert_equal ["Alice"], User.all.map(&:name)
  end

  def test_save_runs_validations_for_updates
    user = User.new("name" => "Alice")
    user.save

    user.name = nil

    assert_equal false, user.save
    assert_equal({ "name" => ["can't be blank"] }, user.errors)
    assert_equal ["Alice"], User.all.map(&:name)
  end

  def test_validations_are_inherited
    admin = Admin.new("name" => "Alice", "role" => nil)

    refute admin.valid?
    assert_equal({ "role" => ["can't be blank"] }, admin.errors)
  end

  def test_errors_returns_a_copy
    user = User.new("name" => nil)
    user.valid?

    errors = user.errors
    errors["name"] << "changed"

    assert_equal({ "name" => ["can't be blank"] }, user.errors)
  end
end
