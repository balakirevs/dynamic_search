require 'dynamic_search/class_methods'

module DynamicSearch
  module ActsAsDynamicallySearchable
    extend ActiveSupport::Concern

    module ClassMethods
      def acts_as_dynamically_searchable(config)
        class_eval do
          include DynamicSearch::ActiveRecord::Concern
        end

        self.dynamic_search_config = config
      end
    end
  end
end
