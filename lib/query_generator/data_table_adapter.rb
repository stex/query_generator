module QueryGenerator

  #A small adapter for jQuery's DataTable plugin. Mostly just parsing and generating
  #data from and for the table
  class DataTableAdapter
    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    attr_reader :offset
    attr_reader :per_page
    attr_reader :search_string
    attr_reader :order_by_columns
    attr_reader :has_data

    def parse_params!(params)
      @offset           = params[:iDisplayStart].to_i if params[:iDisplayStart]
      @per_page         = params[:iDisplayLength].to_i if params[:iDisplayLength]
      @search_string    = params[:sSearch]
      @order_by_columns = []

      @has_data         = !@offset.nil?

      sorting_col_amount = params[:iSortingCols].to_i
      #Find out if the sorting columns were changed client side
      if sorting_col_amount > 0
        (0..sorting_col_amount-1).each do |i|
          column_index = params["iSortCol_#{i}"].to_i
          column_direction = params["sSortDir_#{i}"]
          @order_by_columns << [column_index, column_direction]
        end
      end
    end

  end
end