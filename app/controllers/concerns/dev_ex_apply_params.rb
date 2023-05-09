module DevExApplyParams
  extend ActiveSupport::Concern

  # Просто перевод операторов в SQL
  SEARCH_OPERATORS = ['=' , '<>' , '>' , '>=' , '<' , '<="' , 'startswith' , 'endswith' , 'contains' , 'notcontains']
  SEARCH_OPERATORS_TO_SQL = ['= :text' , '<> :text' , '> :text' , '>= :text' , '< :text' , '<= :text' , "ILIKE :text" , "ILIKE :text" , "ILIKE :text" , "NOT ILIKE :text"]
  SEARCH_OPERATORS_TO_SQL_VALUES = [nil , nil , nil , nil , nil , nil , ":text%" , "%:text" , "%:text%" , "%:text%"]


  # {:search=>nil, :filter=>nil, :pagination=>{:skip=>0, :take=>20},
  #  :totals=>{:total_count=>true, :group_count=>false}, :sort=>nil}

  def search_scope(scope, params)
    return scope unless params.dig(:seach, :search_expr) &&
                        params.dig(:seach, :search_operation) &&
                        params.dig(:seach, :search_value)

    res = apply_filter(scope, params.dig(:seach, :search_expr),
                              params.dig(:seach, :search_operation),
                              params.dig(:seach, :search_value))
    res
  end

  def filter_scope(scope, params)
    return scope unless params[:filter]

    sql_array, values_array = build_filter_where(params: params[:filter])
    scope.where([sql_array.join(' ')].concat(values_array))
  end

  def test_filter(params:)
    sql_array, values_array = build_filter_where(params: params)
    [sql_array.join(' '), values_array]
  end

  # params: [[["description", "=", "Товар 10"], "or", ["description", "=", "Товар 1"]], "and", [["ref1_id", "=", 6], "or", ["ref1_id", "=", 7]]]
  def build_filter_where(params:)
    if params.length == 3 && !params[0].is_a?(Array)
      return build_condition(params[0], params[1], params[2])
    end

    join_condition = nil
    sql_array = []
    values_array = []
    params.each do |param|
      if param.is_a?(Array) && param.any?
        # Если указана связка - то используем ее
        if join_condition
          if join_condition == 'or'
            sql_array.push('OR')
          else
            sql_array.push('AND')
          end
          join_condition = nil
        end
        if param[0].is_a?(Array)
          nested_sql_array, nested_values_array = build_filter_where(params: param)
          sql_array.push('(')
          sql_array.concat(nested_sql_array)
          sql_array.push(')')
          values_array.concat(nested_values_array)
        elsif param[0] == '!' && param[1].is_a?(Array)
          sql_array.push('NOT')
          nested_sql_array, nested_values_array = build_filter_where(params: param[1])
          sql_array.push('(')
          sql_array.concat(nested_sql_array)
          sql_array.push(')')
          values_array.concat(nested_values_array)
        elsif param.length >= 3
          sql, val = build_condition(param[0], param[1], param[2])
          sql_array.concat(sql)
          values_array.concat(val)
        end
      else
        join_condition = param
      end
    end
    [sql_array, values_array]
  end

  def calc_total_count(scope, params)
    scope.count() if params.dig(:totals, :total_count)
  end

  def sort_scope(scope, params)
    sort = params[:sort]
    return scope unless sort && sort.any?

    order_expression = sort.select{|item| item['selector']}
                .map{|item| (item['desc'] == true ? {item['selector'] => :desc} : item['selector']) }
    res = scope.order(order_expression)
    res
  end

  def paginate_scope(scope, params)
    res = scope
    res = res.offset(params.dig(:pagination, :skip)) if params.dig(:pagination, :skip)
    res = res.limit(params.dig(:pagination, :take)) if params.dig(:pagination, :take)
    res
  end

  private

  def apply_filter(scope, field, operator, value)
    sql, val = build_condition(field, operator, value)

    scope.where(sql, val)
  end

  def build_condition(field, operator, value)
    operator_index = SEARCH_OPERATORS.index(operator)
    unless operator_index && operator_index >= 0
      return ['(1=0)',[]]
    end

    sql = SEARCH_OPERATORS_TO_SQL[operator_index]
    val = value
    if sql.to_s.include?('LIKE')
      val = ActiveRecord::Base.send(:sanitize_sql_like, value)
    end

    if SEARCH_OPERATORS_TO_SQL_VALUES[operator_index]
      val = SEARCH_OPERATORS_TO_SQL_VALUES[operator_index].sub(':text', val.to_s)
    end

    [['(' + field + ' ' + sql.gsub(':text','?') + ')'], [val]]
  end
end
