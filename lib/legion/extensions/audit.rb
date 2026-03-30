# frozen_string_literal: true

require 'legion/extensions/audit/version'
require 'legion/extensions/audit/runners/approval_queue'

module Legion
  module Extensions
    module Audit
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core, false

      def self.data_required? # rubocop:disable Legion/Extension/DataRequiredWithoutMigrations
        true
      end

      def data_required?
        true
      end
    end
  end
end
