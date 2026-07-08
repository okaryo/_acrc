# frozen_string_literal: true

module Acrc
  class Error < StandardError; end
  class DatabaseError < Error; end
  class UnknownAttributeError < Error; end
end

require "acrc/model"
require "acrc/sqlite_adapter"
