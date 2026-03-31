# frozen_string_literal: true

module Legion
  module Extensions
    module Audit
      # Raised when post-write SHA-256 verification fails.
      class WriteVerificationError < StandardError; end

      # Raised when the file on disk has been modified since the caller read it.
      class StaleEditError < StandardError; end
    end
  end
end
