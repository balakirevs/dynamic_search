require 'active_support/concern'

module DynamicSearch::Concerns::ActiveRecord
  extend ActiveSupport::Concern

  included do
    class_attribute :dynamic_search_config
  end

  module ClassMethods
    def dynamic_search(query, config = nil)
      config ||= self.dynamic_search_config
      all.merge(DynamicSearch::Processor.new(all, query, config).scope)
    end
  end
end
