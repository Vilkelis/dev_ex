module DevExParseParams
  extend ActiveSupport::Concern

  # {:search=>nil, :filter=>nil, :pagination=>{:skip=>0, :take=>20},
  #  :totals=>{:total_count=>true, :group_count=>false}, :sort=>nil}
  def all_params_parse(params = params)
    res = {}
    res.merge! search_params_parse(params)
    res.merge! filter_params_parse(params)
    res.merge! pagination_params_parse(params)
    res.merge! total_params_parse(params)
    res.merge! sort_params_parse(params)
    res
  end

  private

  def search_params_parse(params = params)
    search_expr = params['searchExpr'] ? JSON.parse(params['searchExpr']) : nil
    search_operation = params['searchOperation'] ? JSON.parse(params['searchOperation']) : nil
    search_value = params['searchValue'] ? JSON.parse(params['searchValue']) : nil
    return {search: nil} unless search_expr && search_operation && search_value

    {search: {search_expr: search_expr,
              search_operation: search_operation,
              search_value: search_value}}
  end

  def filter_params_parse(params = params)
    filter = params['filter'] ? JSON.parse(params['filter']) : nil
    {filter: filter}
  end

  def pagination_params_parse(params = params)
    skip = params['skip'] ? params['skip'].to_i : nil
    take = params['take'] ? params['take'].to_i : nil
    return {pagination: nil} unless skip && take

    {pagination: {skip: skip, take: take}}
  end

  def total_params_parse(params = params)
    return {totals: { total_count: (params['requireTotalCount'] == 'true'),
                      group_count: (params['requireGroupCount'] == 'true')
                    }
            }
  end

  def sort_params_parse(params = params)
    sort = params['sort'] ? JSON.parse(params['sort']) : nil
    {sort: sort}
  end
end
