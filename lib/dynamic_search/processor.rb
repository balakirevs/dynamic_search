require 'dynamic_search/query'

# Processor for dynamic search.
#
# usage:
#
# params = {
#   '0' => {key: 'id', operator: 'eq', value: '1'},
# }
#
# config = {
#   id: {type: :integer}
# }
# processor = DynamicSearch::Processor.new(Model.all, params, config)
# Model.all.merge(processor.scope)
#
#
# Config format:
# {
#   key: {
#     # Required
#     type: :integer || :string || :enum || :datetime,
#
#     # Required for type :enum
#     values: ['value_1', 'value_2'],
#
#     # Optional: uses key OR given value to determine which scope to call
#     # scope receives (operator, value) as arguments.
#     scope: true || :some_scope_name,
#
#     # Opional: adds "OR :attribute IS NULL" to SQL statement
#     # when operator is negative.
#     null: true,
#
#     # Optional: uses given value if attribute_name differs from key
#     attribute_name: :some_column,
#
#     # Optional: use when attribute resides in some other model,
#     # uses rails relations to generate joins.
#     # If given, the scope option affects this class.
#     relation: :parent_model,
#     relation: {parent_model: :granparent_model},
#
#     # Optional: use to modify value coming from params
#     value: lambda{|value| "#{value}"}
# }
#
# Params format:
# {
#   '0' => {
#     # Required: hash key of config
#     key: 'key',
#
#     # Required:
#     # Supported operators are defined in DynamicSearch::Query::OPERATORS
#     operator: 'operator',
#
#     # Required:
#     value: 'value'
#
#     # Opional: adds "OR :attribute IS NULL" to SQL statement
#     null: true,
#   }
# }
class DynamicSearch::Processor
  attr_reader :params, :config

  def initialize(scope, params, config)
    @scope = scope
    @params = params
    @config = config
  end

  def scope
    @params.values.inject(@scope) do |memo, query|
      if (query_scope = DynamicSearch::Query.new(@scope, query, @config).scope)
        if query_scope.joins_values.present?
          memo.joins(query_scope.joins_values).distinct.and(query_scope.distinct).distinct
        else
          memo.distinct.and(query_scope.distinct)
        end
      else
        memo.distinct
      end
    end
  end
end
