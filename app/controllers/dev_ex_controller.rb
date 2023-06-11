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
        if list_params.dig(:group)
          scope = search_scope(scope, list_params)
          scope = filter_scope(scope, list_params)
          total_summary = total_summary_data(scope, list_params) if list_params.dig(:totals, :total_summary)
          total_count = calc_totals(scope, list_params) if list_params.dig(:totals, :total_count)
          res = group_data(scope, list_params)
          total_count = res.count
          data = { data: res }
          data['groupCount'] = total_count if list_params.dig(:totals, :group_count)
          data['summary'] = total_summary if list_params.dig(:totals, :total_summary)
          data['totalCount'] = total_count if list_params.dig(:totals, :total_count)
          render json: data
        else
          scope = search_scope(scope, list_params)
          scope = filter_scope(scope, list_params)
          total_summary = total_summary_data(scope, list_params) if list_params.dig(:totals, :total_summary)
          total_count = calc_totals(scope, list_params) if list_params.dig(:totals, :total_count)
          scope = sort_scope(scope, list_params)
          scope = paginate_scope(scope, list_params)
          res = scope.all
          data = {data: res}
          data['summary'] = total_summary if list_params.dig(:totals, :total_summary)
          data['totalCount'] = total_count if list_params.dig(:totals, :total_count)
          render json: data
        end
      end
      format.html do
      end
    end
  end

  def ref
    @report_data = DevExRef # search_params_parse(DevExRef)
    total_count =  0 # @report_data.count()
    @report_data = @report_data.order('name asc')
                      .offset(params[:skip])
                      .limit(params[:take])
    render json: {data: serialize_ref(@report_data), totalCount: total_count }
  end

  def description
    @report_data = DevExData
    total_count =  0 # @report_data.count()
    @report_data = @report_data.select(:description).distinct.order('description asc')
                      .offset(params[:skip])
                      .limit(params[:take])
    render json: {data: serialize_description(@report_data), totalCount: total_count }
  end

  def start_date
    @report_data = DevExData
    total_count =  0 # @report_data.count()
    @report_data = @report_data.select(:start_date).distinct.order('start_date asc')
                      .offset(params[:skip])
                      .limit(params[:take])
    render json: {data: serialize_start_date(@report_data), totalCount: total_count }
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

  def serialize_description(data)
    data.map{|item| {text: item.description, value: item.description}}
  end

  def serialize_start_date(data)
    data.map{|item| {text: item.start_date, value: item.start_date}}
  end
end
