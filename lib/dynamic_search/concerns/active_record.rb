require 'active_support/concern'

module DynamicSearch::Concerns::ActiveRecord
  extend ActiveSupport::Concern

  included do
    class_attribute :dynamic_search_config
  end

  module ClassMethods
    def dynamic_search(query, config = nil)
      config ||= self.dynamic_search_config
      scope = DynamicSearch::Processor.new(all, query, config).scope
      all.joins(scope.joins_values).distinct
         .and(scope.distinct)
    end
  end
end
