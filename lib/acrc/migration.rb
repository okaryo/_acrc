# frozen_string_literal: true

module Acrc
  class Migration
    attr_reader :version, :name

    def initialize(version, name = nil, &block)
      raise ArgumentError, "migration version must not be empty" if version.to_s.empty?
      raise ArgumentError, "migration requires a block" unless block

      @version = version.to_s
      @name = name
      @block = block
    end

    def up(adapter)
      @block.call(adapter)
    end
  end

  class MigrationRunner
    SCHEMA_MIGRATIONS_TABLE = "acrc_schema_migrations"

    def initialize(adapter)
      @adapter = adapter
    end

    def migrate(migrations)
      ensure_schema_migrations_table
      applied = applied_versions

      pending_migrations(migrations, applied).map do |migration|
        run_migration(migration)
        migration.version
      end
    end

    def applied_versions
      ensure_schema_migrations_table
      adapter
        .execute("SELECT version FROM #{SCHEMA_MIGRATIONS_TABLE} ORDER BY version ASC")
        .map { |row| row["version"] }
    end

    private

    attr_reader :adapter

    def ensure_schema_migrations_table
      adapter.execute(
        "CREATE TABLE IF NOT EXISTS #{SCHEMA_MIGRATIONS_TABLE} " \
        "(version TEXT PRIMARY KEY)"
      )
    end

    def pending_migrations(migrations, applied)
      migrations
        .sort_by(&:version)
        .reject { |migration| applied.include?(migration.version) }
    end

    def run_migration(migration)
      adapter.transaction do
        migration.up(adapter)
        adapter.execute(
          "INSERT INTO #{SCHEMA_MIGRATIONS_TABLE} (version) VALUES (?)",
          [migration.version]
        )
      end
    end
  end
end
