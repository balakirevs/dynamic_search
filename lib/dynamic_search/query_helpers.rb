module DynamicSearch::QueryHelpers
  TRUTHY_VALUES = ['1', 'true', true]

  def query_param_truthy?(value)
    TRUTHY_VALUES.include?(value)
  end

  def query_param_falsy?(value)
    !query_param_truthy?(value)
  end
end
