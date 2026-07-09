# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "acrc"

class RelationTest < Minitest::Test
  class User < Acrc::Model
    table_name "users"
  end

  def setup
    @dir = Dir.mktmpdir("acrc-test-")
    @adapter = Acrc::SQLiteAdapter.new(File.join(@dir, "test.sqlite3"))
    @adapter.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, role TEXT NOT NULL)")
    @adapter.execute("INSERT INTO users (name, role) VALUES (?, ?)", ["Alice", "admin"])
    @adapter.execute("INSERT INTO users (name, role) VALUES (?, ?)", ["Bob", "member"])
    @adapter.execute("INSERT INTO users (name, role) VALUES (?, ?)", ["Carol", "member"])
    User.connection @adapter
  end

  def teardown
    @adapter.close
    FileUtils.remove_entry(@dir)
  end

  def test_where_returns_an_unloaded_relation
    relation = User.where(role: "member")

    assert_instance_of Acrc::Relation, relation
    refute relation.loaded?
  end

  def test_relation_loads_records_when_converted_to_an_array
    relation = User.where(role: "member")

    assert_equal ["Bob", "Carol"], relation.to_a.map(&:name)
    assert relation.loaded?
  end

  def test_relation_is_enumerable
    names = User.where(role: "member").map(&:name)

    assert_equal ["Bob", "Carol"], names
  end

  def test_where_composes_conditions_immutably
    members = User.where(role: "member")
    carol = members.where(name: "Carol")

    refute_same members, carol
    assert_equal ["Bob", "Carol"], members.map(&:name)
    assert_equal ["Carol"], carol.map(&:name)
  end

  def test_all_returns_an_unloaded_relation_for_every_record
    relation = User.all

    refute relation.loaded?
    assert_equal ["Alice", "Bob", "Carol"], relation.map(&:name)
  end

  def test_relation_returns_a_copy_of_loaded_records
    records = User.where(role: "member").to_a
    records.clear

    assert_equal ["Bob", "Carol"], User.where(role: "member").map(&:name)
  end
end
