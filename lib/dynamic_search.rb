require 'dynamic_search/version'
require 'dynamic_search/engine'
require 'dynamic_search/processor'
require 'dynamic_search/concerns'

if defined?(ActionView::Base)
  require 'dynamic_search/view_helpers'
  ActionView::Base.send(:include, DynamicSearch::ViewHelpers)
end

if defined?(ActiveRecord::Base)
  require 'dynamic_search/concerns/active_record'
  ActiveRecord::Base.send(:include, DynamicSearch::Concerns::ActiveRecord)
end
