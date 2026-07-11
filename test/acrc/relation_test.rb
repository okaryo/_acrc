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

  def test_where_accepts_array_values_as_in_conditions
    names = User.where(id: [1, 3]).order(id: :asc).map(&:name)

    assert_equal ["Alice", "Carol"], names
  end

  def test_where_with_an_empty_array_matches_no_records
    assert_empty User.where(id: []).to_a
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

  def test_order_sorts_records
    names = User.all.order(name: :desc).map(&:name)

    assert_equal ["Carol", "Bob", "Alice"], names
  end

  def test_limit_restricts_loaded_records
    names = User.all.order(id: :asc).limit(2).map(&:name)

    assert_equal ["Alice", "Bob"], names
  end

  def test_select_loads_only_selected_columns
    users = User.where(role: "member").select(:id, :name).order(id: :asc).to_a

    assert_equal ["Bob", "Carol"], users.map(&:name)
    assert_equal [2, 3], users.map(&:id)
    refute_respond_to users.first, :role
    assert_raises(Acrc::UnknownAttributeError) { users.first[:role] }
  end

  def test_query_methods_compose_immutably
    base = User.where(role: "member")
    ordered = base.order(name: :desc)
    limited = ordered.limit(1)

    assert_equal ["Bob", "Carol"], base.map(&:name)
    assert_equal ["Carol", "Bob"], ordered.map(&:name)
    assert_equal ["Carol"], limited.map(&:name)
  end

  def test_order_rejects_unsafe_column_names
    assert_raises(Acrc::InvalidIdentifierError) do
      User.all.order("name DESC; DROP TABLE users" => :asc)
    end
  end

  def test_order_rejects_unknown_directions
    error = assert_raises(ArgumentError) do
      User.all.order(name: :sideways)
    end

    assert_equal "order direction must be :asc or :desc", error.message
  end

  def test_limit_rejects_negative_values
    error = assert_raises(ArgumentError) do
      User.all.limit(-1)
    end

    assert_equal "limit must be a non-negative integer", error.message
  end

  def test_select_rejects_empty_columns
    error = assert_raises(ArgumentError) do
      User.all.select
    end

    assert_equal "select columns must not be empty", error.message
  end
end
