module DynamicSearch
  module ViewHelpers
    def dynamic_search_for(model, old_search = nil, options={}, &block)
      columns = model.send(:dynamic_search_columns)
      old_search = nil if model.send(:dynamic_search_is_empty?, old_search)
      dynamic_search(columns, old_search, options, block)
    end

    def dynamic_search(columns, options = {}, &block)
      options[:method] ||= :get
      options[:param_name] ||= :dynamic_search
      options[:clear_search_link] = true if options[:clear_search_link].nil?
      old_search = params[options[:param_name]]&.to_unsafe_h || {}
      content_tag(:div, :class => :dynamic_search) do
        concat( content_tag(:div, :class => :templates) { dynamic_search_input_templates(columns, options) } )
        concat( form_tag({}, options) do
          generate_dynamic_search_controls(columns, old_search, options)
          if block_given?
            concat( content_tag(:div, :class => :dynamic_search_content) do
              concat capture(&block)
            end)
          else
            concat( dynamic_search_controls )
          end
        end)
      end
    end

    def link_to_add_dynamic_search_field
      link_to('javascript:void(0);', :class => 'dynamic_search_add') do
        concat( content_tag(:span) { t('dynamic_search.add_criteria') } )
      end
    end

    def dynamic_search_controls
      @dynamic_search_controls
    end

    private
    def generate_dynamic_search_controls(columns, old_search, options = {})
      @dynamic_search_controls =
        capture do
          concat( content_tag(:div, :class => :dynamic_search_fieldsets) do
            concat( dynamic_search_inputs(columns, old_search, options) )
          end)
          concat( content_tag(:div, :class => :dynamic_search_add_and_submit) do
            concat( link_to_add_dynamic_search_field )
            concat( submit_tag t('dynamic_search.submit'), :class => 'btn' )
            if options[:clear_search_link]
              concat( content_tag(:div) do
                concat( link_to t('dynamic_search.clear'), "#", :class => [:dynamic_search_clear] ) if old_search.present?
              end)
            end
          end)
        end
    end

    def dynamic_search_input_templates(columns, options = {})
      return nil if columns.nil?
      capture do
        columns.each_pair do |col_name, col_options|
          template_column(col_name, col_options, columns, options)
        end
      end
    end

    def dynamic_search_inputs(columns, old_search, options = {})
      counter = 0
      capture do
        if old_search
          old_search.sort.map(&:last).each do |item|
            if item.size == 1
              item = item.values.first
            end
            if item.present? and col_name = item['key'] and col_options = columns[col_name.to_sym]
              search_column(col_name, col_options, columns, options.merge({:index => counter, :operator => item['operator'], :value => item['value'], :old_search => true}))
              counter = counter + 1
            end
          end
        end
        search_column(columns.first[0], columns.first[1], columns, options.merge({:index => 0})) if counter == 0
      end
    end

    def template_column(col_name, col_options, columns, options = {})
      search_column(col_name, col_options, columns, options.merge({:template => true}))
    end

    def search_column(col_name, col_options, columns, options = {})
      options = options.dup
      options[:index] ||= 'INDEX'
      options[:template] ||= false

      fieldset_id = options[:template] ?  "dynamic_search_template_#{col_name}" : "dynamic_search_#{options[:index]}"
      fieldset_style = options[:template] ? 'display:none' : ''
      fieldset_class = options[:template] ? 'dynamic_search_template' : 'dynamic_search_active'

      content_tag(:fieldset, id: fieldset_id, style: fieldset_style, class: fieldset_class) do
         concat name_input_for_column(col_name, col_options, columns, options)
         concat operator_input_for_column(col_name, col_options, columns, options)
         concat value_input_for_column(col_name, col_options, columns, options)
         concat link_to('', 'javascript:void(0);', :class => 'dynamic_search_remove', :style => 'display:none')
       end
    end

    def operators_for_column(col_name, col_options)
      if col_options[:values] && col_options[:type] != :enum
        [
          [t('dynamic_search.operator.matches'), :matches],
          [t('dynamic_search.operator.does_not_match'), :does_not_match]
        ]
      else
        case col_options[:type]
        when :integer, :age
          [
            [t('dynamic_search.operator.eq'), :eq],
            [t('dynamic_search.operator.gteq'), :gteq],
            [t('dynamic_search.operator.lteq'), :lteq]
          ]
        when :string
          if col_name == :any_field
            [[t('dynamic_search.operator.contains'), :matches]]
          else
            [
              [t('dynamic_search.operator.begins_with'), :begins_with],
              [t('dynamic_search.operator.ends_with'), :ends_with],
              [t('dynamic_search.operator.eq'), :eq],
              [t('dynamic_search.operator.contains'), :matches],
              [t('dynamic_search.operator.does_not_contain'), :does_not_match],
            ]
          end
        when :datetime
          [
            [t('dynamic_search.operator.before'), :lteq],
            [t('dynamic_search.operator.after'), :gteq]
          ]
        when :date, :date_future
          [
            [t('dynamic_search.operator.eq'), :eq],
            [t('dynamic_search.operator.before'), :lteq],
            [t('dynamic_search.operator.after'), :gteq]
          ]
        when :boolean
          [
            [t('dynamic_search.operator.yes'), :eq],
            [t('dynamic_search.operator.no'), :not_eq],
          ]
        when :enum
          [
            [t('dynamic_search.operator.eq'), :eq],
            [t('dynamic_search.operator.not_eq'), :not_eq],
          ]
        else
          [col_options[:type]]
        end
      end
    end

    def name_input_for_column(col_name, col_options, columns, options = {})
      input_name = "#{options[:param_name]}[#{options[:index]}][key]"
      select_tag(input_name, options_for_select(columns.map{|c| [ t("dynamic_search.column.#{c[0]}"), c[0]] }, col_name), class: 'dynamic_search_column')
    end

    def operator_input_for_column(col_name, col_options, columns, options = {})
      operators = operators_for_column(col_name, col_options)
      input_name = "#{options[:param_name]}[#{options[:index]}][operator]"
      select_tag(input_name, options_for_select(operators, options[:operator]), class: 'dynamic_search_operator')
    end

    def value_input_for_column(col_name, col_options, columns, options = {})
      input_name = "#{options[:param_name]}[#{options[:index]}][value]"
      input_class = ['dynamic_search_value', col_options[:type]]
      if col_options[:values]
        option_tags = options_for_select(col_options[:values].map{|v| [ t("dynamic_search.value.#{v}"), v] }, options[:value])
        select_tag(input_name, option_tags, class: input_class)
      else
        case col_options[:type]
        when :date, :date_future
          format = 'yyyy-mm-dd'
          text_field_tag(input_name, options[:value], class: input_class, 'data-format' => format, 'data-date-format' => format, placeholder: format.upcase)
        when :datetime
          format = 'yyyy-mm-dd'
          text_field_tag(input_name, options[:value], class: input_class, 'data-format' => format, 'data-date-format' => format, placeholder: format.upcase)
        when :boolean
          hidden_field_tag(input_name, true)
        else
          text_field_tag(input_name, options[:value], class: input_class)
        end
      end
    end
  end
end
