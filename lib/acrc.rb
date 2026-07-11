# frozen_string_literal: true

module Acrc
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
end

require "acrc/model"
require "acrc/relation"
require "acrc/sqlite_adapter"
