module DynamicSearch
  if defined?(::Rails::Engine)
    class Engine < ::Rails::Engine #@private
      isolate_namespace DynamicSearch
    end
  end
end
