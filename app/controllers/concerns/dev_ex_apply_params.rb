module DevExApplyParams
  extend ActiveSupport::Concern

  # Просто перевод операторов в SQL
  SEARCH_OPERATORS = ['=' , '<>' , '>' , '>=' , '<' , '<="' , 'startswith' , 'endswith' , 'contains' , 'notcontains']
  SEARCH_OPERATORS_TO_SQL = ['= :text' , '<> :text' , '> :text' , '>= :text' , '< :text' , '<= :text' , "ILIKE :text" , "ILIKE :text" , "ILIKE :text" , "NOT ILIKE :text"]
  SEARCH_OPERATORS_TO_SQL_VALUES = [nil , nil , nil , nil , nil , nil , ":text%" , "%:text" , "%:text%" , "%:text%"]
  SUMMARY_OPERATORS = ["sum", "min", "max", "avg", "count"]

  def group_data(scope, params)
    return scope unless params.dig(:group)

    group_fields = params.dig(:group).map{|item| item['selector']}
    group_order_expression = sort_expression(params.dig(:group))

    res = []
    if params.dig(:group).last['isExpanded']
      scope = scope.order(order_fields)
      items_order_expression = sort_expression(params.dig(:sort))
      scope = scope.order(items_order_expression) if items_order_expression
      data = scope.all
      res = DevExGroupping.build_data(data, group_fields, only_groups: false)
    else
      select_fields = group_fields.dup
      select_fields.push('COUNT(*) AS count_rows')
      data = scope.select(select_fields).group(group_fields).order(group_order_expression)

      res = DevExGroupping.build_data(data, group_fields, only_groups: true)
    end
    res
  end


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

    sql_array, values_array = build_filter_where_new(params: params[:filter])
    scope.where([sql_array.join(' ')].concat(values_array))
  end

  def test_filter(params:)
    sql_array, values_array = build_filter_where_new(params: params)
    [sql_array.join(' '), values_array]
  end

  def build_filter_where_new(params:)
    sql_array = []
    value_array = []
    index = 0
    while index < params.count
      param = params[index]
      if param.is_a?(Array)
        sql, value = build_filter_where_new(params: param)
        sql_array.push('(')
        sql_array.concat(sql)
        sql_array.push(')')
        value_array.concat(value)
      elsif param == '!'
        sql_array.push('NOT')
      elsif param == 'and'
        sql_array.push('AND')
      elsif param == 'or'
        sql_array.push('OR')
      else
        # Условие - обрабатываем 3 подряд
        sql, value = build_condition(params[index], params[index + 1], params[index + 2])
        sql_array.push(sql)
        value_array.push(value)
        index += 2
      end
      index += 1
    end
    [sql_array, value_array]
  end

  # params: [[["description", "=", "Товар 10"], "or", ["description", "=", "Товар 1"]],
  # "and", [["ref1_id", "=", 6], "or", ["ref1_id", "=", 7]]]
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

  def calc_totals(scope, params)
    scope.count() if params.dig(:totals, :total_count)
  end

  def sort_expression(sort)
    return nil unless sort && sort.any?

    sort.select{|item| item['selector']}
                .map{|item| (item['desc'] == true ? {item['selector'] => :desc} : item['selector']) }
  end

  def sort_scope(scope, params)
    sort = params[:sort]
    return scope unless sort && sort.any?

    res = scope.order(sort_expression(sort))
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

  module DevExGroupping
    extend self

    # Строит из проских данных data данные для структуры с группировкой DevExtreme
    # group_fields - перечень полей группировки
    # набор данных должен содержать служебное поле count_rows
    # only_groups = true - набор данных представляет собой только группы (без строк)
    # only_groups = false - набор данных содержить отсортированные данные без группировки.
    # нужно произвести группировку и в последнем уровне привести сами данные
    def build_data(data, group_fields, only_groups: false)
      return build_groupped_data(data, group_fields) if only_groups

      res = []
      keys = Array.new(group_fields.count)
      cur_group_items = []
      data.each do |row|
        group_field_values = group_fields.map{|item| row[item]}
        dif_index = get_first_diferent_value_index(keys, group_field_values)
        keys = group_field_values.clone

        if dif_index == 0
          cur_group_items = []
          item, _ = build_item_tree(cur_group_items, group_field_values, row['count_rows'])
          res.push(item[0])
          unless only_groups
            cur_group_items.last[:items] = [row]
            cur_group_items.last[:count] = 1
          end
        elsif dif_index.nil? && !only_groups
          cur_group_items.last[:items].push(row)
          cur_group_items.last[:count] += 1
        else
          group_field_values.shift(dif_index)
          group_subitems = []
          item, _ = build_item_tree(group_subitems, group_field_values, row['count_rows'])
          cur_group_items[dif_index - 1][:items].push(item[0])
          cur_group_items[dif_index - 1][:count] += 1
          unless only_groups
            cur_group_items.last[:items] = [row]
            cur_group_items.last[:count] = 1
          end
        end
      end
      res
    end

    def build_groupped_data(data, group_fields)
      res = []
      keys = Array.new(group_fields.count)
      cur_group_items = []
      data.each do |row|
        group_field_values = group_fields.map{|item| row[item]}
        dif_index = get_first_diferent_value_index(keys, group_field_values)
        keys = group_field_values.clone

        if dif_index == 0
          cur_group_items = []
          item, _ = build_item_tree(cur_group_items, group_field_values, row['count_rows'])
          res.push(item[0])
        else
          group_field_values.shift(dif_index)
          group_subitems = []
          item, _ = build_item_tree(group_subitems, group_field_values, row['count_rows'])
          cur_group_items[dif_index - 1][:items].push(item[0])
          cur_group_items[dif_index - 1][:count] += 1
        end
      end
      res
    end

    # Обрабатывает группы одной записи.Возвращает первый item и кол-во вложенных.
    # так же возвращает все созданные items в массив group_items
    def build_item_tree(group_items, group_field_values, count_value)
      return [nil, count_value] unless group_field_values.any?

      subitem = {key: group_field_values.shift}
      group_items.push(subitem)
      subitem[:items], subitem[:count] = build_item_tree(group_items, group_field_values, count_value)

      return [[subitem], 1]
    end

    # Возвращает первый индекс в котором данные различаются в двух равновеликих массивах значений
    def get_first_diferent_value_index(array_1, array_2)
      array_1.each_with_index do |val_1, index|
        return index if val_1 != array_2[index]
      end

      nil
    end
  end
end
