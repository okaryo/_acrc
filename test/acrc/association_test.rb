# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "acrc"

class AssociationTest < Minitest::Test
  class User < Acrc::Model
    table_name "users"
    attribute :id, :integer
  end

  class Post < Acrc::Model
    table_name "posts"
    attribute :id, :integer
    attribute :user_id, :integer
    belongs_to :user, class_name: User, foreign_key: :user_id
  end

  User.has_many :posts, class_name: Post, foreign_key: :user_id

  def setup
    @dir = Dir.mktmpdir("acrc-test-")
    @adapter = Acrc::SQLiteAdapter.new(File.join(@dir, "test.sqlite3"))
    @adapter.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)")
    @adapter.execute("CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER, title TEXT NOT NULL)")
    @adapter.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
    @adapter.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])
    @adapter.execute("INSERT INTO posts (user_id, title) VALUES (?, ?)", [1, "Hello"])
    @adapter.execute("INSERT INTO posts (user_id, title) VALUES (?, ?)", [1, "Second"])
    @adapter.execute("INSERT INTO posts (user_id, title) VALUES (?, ?)", [2, "Bob Post"])
    @adapter.execute("INSERT INTO posts (user_id, title) VALUES (?, ?)", [nil, "Orphan"])
    User.connection @adapter
    Post.connection @adapter
  end

  def teardown
    @adapter.close
    FileUtils.remove_entry(@dir)
  end

  def test_belongs_to_loads_the_associated_record_from_the_foreign_key
    post = Post.find(1)

    user = post.user

    assert_instance_of User, user
    assert_equal 1, user.id
    assert_equal "Alice", user.name
  end

  def test_belongs_to_returns_nil_when_foreign_key_is_nil
    post = Post.find(4)

    assert_nil post.user
  end

  def test_belongs_to_raises_when_foreign_key_was_not_loaded
    post = Post.select(:id, :title).where(id: 1).to_a.first

    error = assert_raises(Acrc::UnknownAttributeError) do
      post.user
    end

    assert_equal "unknown attribute: user_id", error.message
  end

  def test_belongs_to_reflects_current_foreign_key_value
    post = Post.find(1)

    post.user_id = 2

    assert_equal "Bob", post.user.name
  end

  def test_has_many_returns_a_lazy_relation_for_matching_foreign_keys
    user = User.find(1)

    relation = user.posts

    assert_instance_of Acrc::Relation, relation
    refute relation.loaded?
    assert_equal ["Hello", "Second"], relation.order(id: :asc).to_a.map(&:title)
  end

  def test_has_many_relation_can_be_composed_before_execution
    user = User.find(1)

    titles = user.posts.where(title: "Second").limit(1).to_a.map(&:title)

    assert_equal ["Second"], titles
  end

  def test_has_many_reflects_current_primary_key_value
    user = User.find(1)

    user.id = 2

    assert_equal ["Bob Post"], user.posts.to_a.map(&:title)
  end

  def test_has_many_raises_when_primary_key_was_not_loaded
    user = User.select(:name).where(id: 1).to_a.first

    error = assert_raises(Acrc::UnknownAttributeError) do
      user.posts
    end

    assert_equal "unknown attribute: id", error.message
  end

  def test_belongs_to_in_a_loop_shows_n_plus_one_queries
    @adapter.clear_query_log

    posts = Post.all.order(id: :asc).to_a
    names = posts.map { |post| post.user&.name }

    select_queries = @adapter.query_log.select { |entry| entry[:sql].start_with?("SELECT") }
    assert_equal ["Alice", "Alice", "Bob", nil], names
    assert_equal 4, select_queries.length
    assert_equal ["SELECT * FROM posts ORDER BY id ASC", []], select_queries[0].values_at(:sql, :binds)
    assert_equal ["SELECT * FROM users WHERE id = ?", [1]], select_queries[1].values_at(:sql, :binds)
    assert_equal ["SELECT * FROM users WHERE id = ?", [1]], select_queries[2].values_at(:sql, :binds)
    assert_equal ["SELECT * FROM users WHERE id = ?", [2]], select_queries[3].values_at(:sql, :binds)
  end

  def test_preload_loads_belongs_to_associations_in_one_additional_query
    @adapter.clear_query_log

    posts = Post.all.order(id: :asc).preload(:user).to_a
    names = posts.map { |post| post.user&.name }

    select_queries = @adapter.query_log.select { |entry| entry[:sql].start_with?("SELECT") }
    assert_equal ["Alice", "Alice", "Bob", nil], names
    assert_equal 2, select_queries.length
    assert_equal ["SELECT * FROM posts ORDER BY id ASC", []], select_queries[0].values_at(:sql, :binds)
    assert_equal ["SELECT * FROM users WHERE id IN (?, ?)", [1, 2]], select_queries[1].values_at(:sql, :binds)
  end

  def test_model_preload_starts_from_all_records
    assert_equal ["Alice", "Alice", "Bob", nil], Post.preload(:user).order(id: :asc).map { |post| post.user&.name }
  end

  def test_preload_rejects_unknown_associations
    error = assert_raises(ArgumentError) do
      Post.all.preload(:missing)
    end

    assert_equal "unknown association: missing", error.message
  end

  def test_preload_only_supports_belongs_to_for_now
    error = assert_raises(Acrc::NotImplementedError) do
      User.all.preload(:posts)
    end

    assert_equal "preload only supports belongs_to associations", error.message
  end
end
