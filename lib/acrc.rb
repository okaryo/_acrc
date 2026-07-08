# frozen_string_literal: true

module Acrc
  class Error < StandardError; end
  class DatabaseError < Error; end
end

require "acrc/sqlite_adapter"
