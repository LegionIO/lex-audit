# frozen_string_literal: true

require 'sequel'

# Shared in-memory SQLite database used by audit-related specs.
# Loaded once via spec_helper so that both audit_spec.rb and
# verified_write_spec.rb share the same DB constant and AuditLog model class,
# avoiding superclass-mismatch errors when all specs run together.
Sequel.default_timezone = :utc

DB = Sequel.sqlite
DB.create_table(:audit_log) do
  primary_key :id
  String   :event_type,     null: false, size: 50
  String   :principal_id,   null: false, size: 255
  String   :principal_type, null: false, size: 20
  String   :action,         null: false, size: 100
  String   :resource,       null: false, size: 500
  String   :source,         null: false, size: 20
  String   :node,           null: false, size: 255
  String   :status,         null: false, size: 20
  Integer  :duration_ms,    null: true
  column   :detail,         :text, null: true
  column   :context_snapshot, :text, null: true
  String   :record_hash,    null: false, size: 64
  String   :prev_hash,      null: false, size: 64
  DateTime :created_at,     null: false
end

module Legion
  module Data
    module Model
      class AuditLog < Sequel::Model(DB[:audit_log]); end # rubocop:disable Legion/Framework/EagerSequelModel
    end
  end
end

$LOADED_FEATURES << 'legion/data/models/audit_log'
