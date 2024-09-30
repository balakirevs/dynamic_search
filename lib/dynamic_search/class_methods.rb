module DynamicSearch
  module ClassMethods
    def dynamic_search_is_empty?(params)
      params.blank? || params.select{|key, value| value["value"].present? }.blank?
    end

    private
      
    def dynamic_search_to_ransack(params)
      return {} unless params
      params = params.deep_dup
      g = 1
      q = {
        'g' => {
          '0' => {
            'm' => 'and'
          }
        }
      }
      params.each_pair do |index, args|
        if args['name'] == 'any_field'
          q['g'][(g+=1).to_s] = {
            'm' => 'or',
            'c' => {}
          }
          self.dynamic_search_columns.each_with_index do |col, i|
            q['g'][g.to_s]['c'][i.to_s] = {}
            c = q['g'][g.to_s]['c'][i.to_s]
            if col.first == :string && col.last != :any_field
              c['a'] = { '0' => { 'name' => col.last.to_s } }
              c['v'] = { '0' => { 'value' => args['value'] } }
            end
            c['p'] = args['operator']
          end
        else
          col = dyn_search_column(args['name'])
          if col and col[0] == :age and col[2].present?
            args = age_to_date(args)
            args['name'] = col[2].to_s
          end
          q['g']['0']['c'] ||= {}
          size = q['g']['0']['c'].size
          q['g']['0']['c'][size.to_s] = {}
          c = q['g']['0']['c'][size.to_s]

          c['a'] = { '0' => { 'name' => args['name'] } }
          c['p'] = args['operator']
          c['v'] = { '0' => { 'value' => args['value'] } }
        end
      end
      q
    end

    def dyn_search_column(name)
      dynamic_search_columns.select{|c| c[1] == name.to_sym}.first
    end

    def age_to_date(args)
      args['operator'] =
        case args['operator']
        when 'gt' then 'lt'
        when 'lt' then 'gt'
        else args['operator']
        end
      if args['value'].match(/^[0-9]+$/)
        args['value'] = (Date.today - args['value'].to_i.years).to_s
      end
      args
    end
  end
end
