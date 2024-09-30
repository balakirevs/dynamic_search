require 'active_record'

class TestResource < ActiveRecord::Base
  cattr_accessor :columns
  self.columns = []

  def self.column(name, sql_type = nil, default = nil, null = true)
    columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
  end

  belongs_to :parent_resource, class_name: 'TestResource'

  column :name, :string
  column :id, :integer
end
