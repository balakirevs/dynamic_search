require 'active_record'

class TestResource < ActiveRecord::Base
  cattr_accessor :columns
  self.columns = []

  def self.column(name, sql_type = :string, default = nil, null = true)
    type = ActiveModel::Type.lookup(sql_type)
    columns << { name: name.to_s, type: type, default: default, null: null }
  end

  belongs_to :parent_resource, class_name: 'TestResource'

  column :name, :string
  column :id, :integer
end
