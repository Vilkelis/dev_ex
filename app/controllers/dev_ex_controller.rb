class DevExController < ApplicationController
  include DevExParseParams
  include DevExApplyParams

  # При фильтрации нужно учитывать допустимые операторы для полей
  # Для группировки достаточно реализовать фильтры

  def index
    respond_to do |format|
      format.json do
        list_params = all_params_parse(params)

        scope = DevExData
        scope = search_scope(scope, list_params)
        scope = filter_scope(scope, list_params)
        total_count = calc_total_count(scope, list_params)
        scope = sort_scope(scope, list_params)
        scope = paginate_scope(scope, list_params)

        render json: { data: scope.all, 'totalCount' => total_count }
      end
      format.html do
      end
    end
  end

  def ref
    @report_data = DevExRef # search_params_parse(DevExRef)
    total_count =  0 # @report_data.count()
    @report_data = @report_data.order('name asc')
                     # .offset(params[:skip])
                     # .limit(params[:take])
    render json: {data: serialize_ref(@report_data), totalCount: total_count }
  end

  private

  def filter(scope)

    return scope
  end

  # "filter", ok
  # "group",
  # "groupSummary",
  # "parentIds",
  # "requireGroupCount", ok
  # "requireTotalCount", ok
  # "searchExpr", ok
  # "searchOperation", ok
  # "searchValue", ok
  # "select",
  # "sort", ok
  # "skip", ok
  # "take", ok
  # "totalSummary",
  # "userData"


  # Для каждой модели свой сериализатор
  def serialize_ref(data)
    data.map{|item| {text: item.name, value: item.id}}
  end

end
