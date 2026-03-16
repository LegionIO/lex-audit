# frozen_string_literal: true

require 'legion/extensions/audit'

RSpec.describe Legion::Extensions::Audit do
  it 'has a version number' do
    expect(Legion::Extensions::Audit::VERSION).not_to be_nil
  end

  it 'reports data_required? as true (class method)' do
    expect(described_class.data_required?).to be true
  end

  it 'reports data_required? as true (instance method)' do
    obj = Object.new.extend(described_class)
    expect(obj.data_required?).to be true
  end
end
