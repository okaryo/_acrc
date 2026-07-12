# frozen_string_literal: true

module Acrc
  Column = Struct.new(:name, :type, :nullable, :primary_key, :default, keyword_init: true)

  class Error < StandardError; end
  class DatabaseError < Error; end
  class ConstraintError < DatabaseError; end
  class ConfigurationError < Error; end
  class DestroyedRecordError < Error; end
  class InvalidIdentifierError < Error; end
  class NotImplementedError < Error; end
  class RecordNotFound < Error; end
  class StaleRecordError < Error; end
  class TypeCastError < Error; end
  class UnknownAttributeError < Error; end
  class UnknownTypeError < Error; end

  class ValidationError < Error
    attr_reader :record

    def initialize(record)
      @record = record
      super("validation failed: #{format_errors(record.errors)}")
    end

    private

    def format_errors(errors)
      return "unknown error" if errors.empty?

      errors.flat_map do |name, messages|
        messages.map { |message| "#{name} #{message}" }
      end.join(", ")
    end
  end
end

require "acrc/model"
require "acrc/migration"
require "acrc/relation"
require "acrc/sqlite_adapter"
