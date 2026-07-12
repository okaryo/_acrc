# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "acrc"

class CallbackTest < Minitest::Test
  class User < Acrc::Model
    table_name "users"
    attribute :id, :integer
    validates_presence_of :name
    before_save :normalize_name
    after_save :remember_saved_name

    def callback_log
      @callback_log ||= []
    end

    private

    def normalize_name
      callback_log << "normalize_name"
      self.name = name.strip if respond_to?(:name) && name
    end

    def remember_saved_name
      callback_log << "remember_saved_name:#{name}"
    end
  end

  class Admin < User
    table_name "users"

    before_save do
      callback_log << "admin_before_save"
      self[:role] = "admin" unless attributes.key?("role")
    end
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

  def test_before_save_runs_before_insert
    user = User.new("name" => " Alice ")

    assert_equal true, user.save

    assert_equal ["normalize_name", "remember_saved_name:Alice"], user.callback_log
    assert_equal [{ "name" => "Alice" }], @adapter.execute("SELECT name FROM users")
  end

  def test_before_save_runs_before_update
    user = User.new("name" => "Alice")
    user.save
    user.callback_log.clear

    user.name = " Bob "
    user.save

    assert_equal ["normalize_name", "remember_saved_name:Bob"], user.callback_log
    assert_equal [{ "name" => "Bob" }], @adapter.execute("SELECT name FROM users WHERE id = ?", [user.id])
  end

  def test_callbacks_do_not_run_when_validation_fails
    user = User.new("name" => nil)

    assert_equal false, user.save

    assert_equal [], user.callback_log
    assert_empty @adapter.execute("SELECT * FROM users")
  end

  def test_callbacks_are_inherited_and_run_parent_callbacks_first
    admin = Admin.new("name" => " Alice ")

    assert_equal true, admin.save

    assert_equal ["normalize_name", "admin_before_save", "remember_saved_name:Alice"], admin.callback_log
    assert_equal [{ "name" => "Alice", "role" => "admin" }], @adapter.execute("SELECT name, role FROM users")
  end

  def test_callback_registration_requires_a_method_name_or_block
    error = assert_raises(ArgumentError) do
      Class.new(Acrc::Model) do
        before_save
      end
    end

    assert_equal "before_save requires a method name or block", error.message
  end
end
