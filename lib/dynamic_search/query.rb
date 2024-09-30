require 'dynamic_search/query_helpers'

class DynamicSearch::Query
  include DynamicSearch::QueryHelpers

  class UnallowedOperator < ::Exception
  end

  class InvalidValue < ::Exception
  end

  class MissingRequiredKey < ::Exception
  end

  class UnsupportedType < ::Exception
  end

  REQUIRED_KEYS = [:key, :operator, :value].freeze

  SUPPORTED_TYPES = [:integer, :string, :enum, :year, :month, :date, :date_future, :datetime, :boolean].freeze

  OPERATORS = {
    integer:     [:eq, :not_eq, :gteq, :lteq, :in, :not_in],
    string:      [:matches, :does_not_match, :begins_with, :ends_with, :eq, :not_eq],
    enum:        [:eq, :not_eq, :in, :not_in],
    year:        [:eq, :gteq, :lteq],
    month:       [:eq, :gteq, :lteq, :eq_since, :gteq_since, :lteq_since],
    date:        [:eq, :gteq, :lteq],
    date_future: [:eq, :gteq, :lteq],
    datetime:    [:eq, :gteq, :lteq],
    boolean:     [:eq, :not_eq]
  }.freeze

  NEGATIVE_OPERATORS = [:not_eq, :does_not_match, :not_in].freeze

  attr_accessor :query, :config

  def initialize(_scope, _query, _config)
    @query = _query
    @config = _config

    check_query_for_missing_keys!

    @scope = query_config[:relation].present? ? _scope.joins(query_config[:relation]) : _scope
  end

  def query_config
    @config[query_key]
  end

  def arel_query
    arel = scope_klass.arel_table[attribute_name]
    aq = arel.send(operator_for_arel, value_for_arel)
    if query_param_truthy?(@query[:null] || query_config[:null]) and NEGATIVE_OPERATORS.include?(operator)
      aq = aq.or(arel.eq(nil))
    end
    aq
  end

  def scope
    return nil if value.blank?
    if custom_scope?
      scope_klass.send(custom_scope_name, operator, value)
    else
      @scope.where(arel_query)
    end
  end

  def operator
    oper = @query[:operator].to_sym
    if OPERATORS[type].include?(oper)
      oper
    else
      raise UnallowedOperator.new(@query), "Query (#{@query}) has unallowed operator: #{oper}"
    end
  end

  def attribute_name
    (query_config[:attribute_name] || query_key).to_sym
  end

  def value
    val = query_config[:value].is_a?(Proc) ? query_config[:value].call(@query[:value]) : @query[:value]
    return nil if val.nil? || val.to_s.strip.length == 0
    case type
    when :string
      val.to_s
    when :integer
      val.to_s.include?(',') ? val.split(',').map(&:to_i) : val.to_i
    when :enum
      val.split(',').each do |v|
        unless allowed_values.include?(v)
          raise InvalidValue.new(@query), "Query (#{@query}) has invalid value: #{v}"
        end
      end
      val
    when :year
      val.to_s
    when :month
      val.to_s
    when :date, :date_future
      Date.parse(val.to_s)
    when :datetime
      DateTime.parse(val.to_s)
    when :boolean
      if ['1', 'true', true].include?(val)
        true
      elsif ['0', 'false', false].include?(val)
        false
      end
    end
  end

  def value_for_arel
    case type
    when :string
      if [:matches, :does_not_match].include?(operator)
        "%#{value}%"
      elsif [:begins_with].include?(operator)
        "#{value}%"
      elsif [:ends_with].include?(operator)
        "%#{value}"
      else
        value
      end
    when :enum
      if [:in, :not_in].include?(operator)
        value.split(',')
      else
        value
      end
    else
      value
    end
  end

  def type
    t = query_config[:type].to_sym
    unless SUPPORTED_TYPES.include?(t)
      raise UnsupportedType.new(query_config), "Config (#{query_config}) has unsupported type: #{t}"
    end
    t
  end

  def scope_klass
    @scope_klass ||=
      if query_config[:relation]
        resolve_relation(@scope.klass, query_config[:relation])
      else
        @scope.klass
      end
  end

  def operator_for_arel
    {
      begins_with: :matches,
      ends_with: :matches
    }[operator] || operator
  end

  private
  def resolve_relation(klass, relation)
    if relation.is_a?(Hash)
      resolve_relation(klass.reflect_on_association(relation.first.first).klass, relation.first.last)
    elsif relation.is_a?(Symbol)
      klass.reflect_on_association(relation).klass
    else
      raise
    end
  end

  def allowed_values
    query_config[:values] || []
  end

  def check_query_for_missing_keys!
    if missing_required_keys.length > 0
      raise MissingRequiredKey.new(@query), "Query (#{@query}) has missing keys: #{missing_required_keys}"
    end
  end

  def missing_required_keys
    (REQUIRED_KEYS - @query.keys.map(&:to_sym))
  end

  def query_key
    @query[:key].to_sym
  end

  def custom_scope?
    query_config[:scope].present?
  end

  def custom_scope_name
    if query_config[:scope].is_a?(Symbol) || query_config[:scope].is_a?(String)
      query_config[:scope]
    else
      query_key
    end
  end

  def use_outer_join?
    NEGATIVE_OPERATORS.include?(operator)
  end
end
