"""
    Events

Holds event level information.

# Fields
- `ids::Vector{String}`: Unique identifier for each event.
- `dates::Vector{Date}`: Date on which the event occurred.
- `firms::Vector{PooledVector}`: Identifier of the firm associated with the event.
- `markets::Vector{PooledVector}`: Identifier of the market associated with the event.
"""
struct Events
  ids::Vector{String}
  dates::Vector{Date}
  firms::PooledVector
  markets::PooledVector
end

"""
    Data_Firms

Holds firm level data.

# Fields
- `ids::Vector{String}`: Unique identifier for each firm.
- `dates::Vector{Date}`: Date on which the observation has occured.
- `columns::Vector{PooledVector}`: Column names of the data matrix.
- `data::Matrix{Float64}`: Matrix of firm level data.
"""
struct Data_Firms
  ids::PooledVector
  dates::Vector{Date}
  columns::Vector{Symbol}
  data::Matrix{Float64}
end

"""
    Data_Markets

Holds market level data.

# Fields
- `ids::Vector{String}`: Unique identifier for each market.
- `dates::Vector{Date}`: Date on which the observation has occured.
- `columns::Vector{PooledVector}`: Column names of the data matrix.
- `data::Matrix{Float64}`: Matrix of market level data.
"""
struct Data_Markets
  ids::PooledVector
  dates::Vector{Date}
  columns::Vector{Symbol}
  data::Matrix{Float64}
end

function Events(df::DataFrame; col_id::String, col_date::String, col_firms::String, col_markets::String)
  @assert allunique(df[!, col_id])

  events = Events(
    string.(df[!, col_id]),
    Date.(df[!, col_date]),
    PooledArray(df[!, col_firms]),
    PooledArray(df[!, col_markets]),
  )

  return events
end

function Data_Markets(df::DataFrame; col_ids::String, col_dates::String, cols_other::Vector{String})

  dates = Date.(df[!, col_dates])
  ids = PooledArray(String.(df[!, col_ids]))

  data = fill(NaN, length(dates), length(cols_other))
  for (i, col) in enumerate(cols_other)
    data_current = df[!, col]
    idx_nomiss = findall(.!(ismissing.(data_current)))

    data[idx_nomiss, i] = data_current[idx_nomiss]
  end

  data_markets = Data_Markets(
    ids,
    dates,
    Symbol.(cols_other),
    data
  )

  return data_markets
end

function Data_Firms(df::DataFrame; col_ids::String, col_dates::String, cols_other::Vector{String})

  dates = Date.(df[!, col_dates])
  ids = PooledArray(String.(df[!, col_ids]))

  data = fill(NaN, length(dates), length(cols_other))
  for (i, col) in enumerate(cols_other)
    data_current = df[!, col]
    idx_nomiss = findall(.!(ismissing.(data_current)))

    data[idx_nomiss, i] = data_current[idx_nomiss]
  end

  data_firms = Data_Firms(
    ids,
    dates,
    Symbol.(cols_other),
    data
  )

  return data_firms
end

"""
    Timeline

Internal use only. Represents the timeline of an event, given a particular estimation, event and post window.

# Fields
- `estimation_absolute::Vector{Int}`: Absolute postions of the estimation window.
- `event_absolute::Vector{Int}`: Absolute postions of the event window.
- `post_absolute::Vector{Int}`: Absolute postions of the post window.
- `estimation_relative::Vector{Int}`: Relative postions of the estimation window.
- `event_relative::Vector{Int}`: Relative postions of the event window.
- `post_relative::Vector{Int}`: Relative postions of the post window.
- `relative_to_absolute::Dict{Int,Int}`: Dictionary translating relative to absolute.
"""
struct Timeline
  estimation_absolute::Vector{Int}
  event_absolute::Vector{Int}
  post_absolute::Vector{Int}
  estimation_relative::Vector{Int}
  event_relative::Vector{Int}
  post_relative::Vector{Int}
  relative_to_absolute::Dict{Int,Int}
end

function Timeline(estimation::Vector{Tuple{Int,Int}}, event::Vector{Tuple{Int,Int}}, post::Vector{Tuple{Int,Int}})

  ## TODO: This does no longer work once the estimation window is in front of
  #the event window. Think about this once the case arises... (06.03.2025,
  #17:32)
  borders_relative_estimation = window_create_largest(estimation)
  borders_relative_event = window_create_largest(event)
  borders_relative_post = window_create_largest(post)

  estimation_window_relative = collect(borders_relative_estimation[1]:borders_relative_estimation[2])
  event_window_relative = collect(borders_relative_event[1]:borders_relative_event[2])
  post_window_relative = collect(borders_relative_post[1]:borders_relative_post[2])

  ## Absolute:
  estimation_window_start = 1
  estimation_window_end = estimation_window_start + (length(estimation_window_relative) - 1)
  event_window_start = estimation_window_end + 1
  event_window_end = event_window_start + (length(event_window_relative) - 1)
  post_window_start = event_window_end + 1
  post_window_end = post_window_start + (length(post_window_relative) - 1)

  estimation_window_absolute = collect(estimation_window_start:estimation_window_end)
  event_window_absolute = collect(event_window_start:event_window_end)
  post_window_absolute = collect(post_window_start:post_window_end)

  ## Make sure they do not intersect:
  relative_all = vcat(estimation_window_relative, event_window_relative, post_window_relative)
  absolute_all = eachindex(relative_all)
  @assert allunique(relative_all)


  timeline = Timeline(
    estimation_window_absolute,
    event_window_absolute,
    post_window_absolute,
    estimation_window_relative,
    event_window_relative,
    post_window_relative,
    Dict(relative_all .=> absolute_all)
  )

  return timeline
end

function window_create_largest(x::Vector{Tuple{Int64,Int64}})

  counter = 1
  values_all = fill(0, length(x) * 2)
  for t in x
    values_all[counter] = t[1]
    values_all[counter+1] = t[2]
    counter += 2
  end

  return extrema(values_all)
end

struct Model_Expected_Returns
  dependent::Symbol
  independent::Vector{Symbol}
end

function variables_get_firm(mdl::Model_Expected_Returns)
  [mdl.dependent]
end

function variables_get_market(mdl::Model_Expected_Returns)
  mdl.independent
end

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Estimation Data
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
struct Data_Window
  ## Identifiers:
  id::String
  ## Dates:
  date_orig::Date
  date_final::Date
  date_all::Vector{Union{Nothing,Date}}
  data::Matrix{Float64}
  data_col_names::Vector{Symbol}
end

function Data_Window(template::Timeline, events::Events, firms::Data_Firms, markets::Data_Markets, variables_firm::Vector{Symbol}, variables_market::Vector{Symbol}, shift::Int64)
  ## TODO(florian): Make sure this works when tings are out of order... (22.05.2023, 08:00)

  ## Locate column positions:
  variables_all = vcat(variables_market, variables_firm)
  idx_data_market_variables = intersect_where(variables_market, markets.columns)
  idx_data_firm_variables = intersect_where(variables_firm, firms.columns)
  idx_window_market_variables = 1:length(idx_data_market_variables)
  idx_window_firm_variables = (length(idx_window_market_variables)+1):(length(idx_window_market_variables)+length(idx_data_firm_variables))

  ## NOTE: To keep the estimates in the order of the events while also
  #allowing subsetting of the data that is statistically likely to be
  #efficient.  (06.03.2025, 19:07)
  event_position_lookup = Dict(events.ids .=> eachindex(events.ids))
  relative_all = vcat(template.estimation_relative, template.event_relative, template.post_relative)
  n_events = length(events.ids)
  markets_all = unique(events.markets)

  n_matrix_rows = length(template.relative_to_absolute)
  n_matrix_cols = length(variables_all)
  matrix_template = fill(NaN, n_matrix_rows, n_matrix_cols)
  event_data = Vector{Data_Window}(undef, n_events)
  counter = 1
  for m in markets_all
    idx_market = findall(markets.ids .== m)
    data_market = @view markets.data[idx_market, :]
    dateline = @view markets.dates[idx_market]

    ## NOTE(florian): Get all firms that are on the current market. (17.05.2023, 10:33)
    firms_relevant = unique(events.firms[findall(events.markets .== m)])
    for f in firms_relevant
      idx_firm = findall(firms.ids .== f)
      data_firm = @view firms.data[idx_firm, :]
      dates_firm = @view firms.dates[idx_firm]

      ## NOTE(florian): Get all Events (17.05.2023, 10:44)
      idx_dates = findall((events.markets .== m) .* (events.firms .== f))
      event_dates = @view events.dates[idx_dates]
      event_ids = @view events.ids[idx_dates]

      for idx_event_date in eachindex(event_dates)
        ## Initialize stuff:
        data_window = copy(matrix_template)
        window_dates = Array{Union{Nothing,Date},1}(nothing, n_matrix_rows)
        event_date_current_orig = event_dates[idx_event_date]
        event_id_current = event_ids[idx_event_date]

        ## Locate event day:
        shift_current = 0
        idx_event_day = findfirst(dateline .== event_date_current_orig)

        while isnothing(idx_event_day) && (shift_current <= shift)
          idx_event_day = findfirst(dateline .== (event_date_current_orig + Day(shift_current)))
          shift_current += 1
        end

        if isnothing(idx_event_day)
          ## NOTE(florian): Just jump to creation of
          ## data_window_final and leave everything empty?
          ## (22.05.2023, 14:32)
          event_date_current_final = event_date_current_orig
          @goto data_assembly
        end

        ## Locate market data relative to the event day:
        market_rel = collect(eachindex(dateline) .- idx_event_day)
        event_date_current_final = dateline[idx_event_day]

        ## Fill data matrix:
        ## TODO(florian): I'm sure this is nowhere near efficient, look into it later, just get it right for now. (22.05.2023, 14:14)
        for (i, idx_rel) in enumerate(relative_all)
          ## 1) Try to locate that relative position in the market data:
          idx_market_current = findfirst(idx_rel .== market_rel)

          ## 2) Copy market data into the matrix:
          if !isnothing(idx_market_current)
            # idx_data_market_variables
            # idx_data_firm_variables
            # idx_window_market_variables
            # idx_window_firm_variables
            data_window[i, idx_window_market_variables] = data_market[idx_market_current, idx_data_market_variables]
            window_dates[i] = dateline[idx_market_current]

            ## 3) Find that date on the dateline:
            date_current = dateline[idx_market_current]

            ## 4) Find that date in the firm data:
            idx_firm_current = findfirst(date_current .== dates_firm)

            ## 5) Copy firm data into the matrix:
            if !isnothing(idx_firm_current)
              data_window[i, idx_window_firm_variables] = data_firm[idx_firm_current, idx_data_firm_variables]
            end
          end
        end

        ## Assemble final WindowData:
        @label data_assembly

        ## Data:
        data_window_final = Data_Window(
          event_id_current,
          event_date_current_orig,
          event_date_current_final,
          window_dates,
          data_window,
          variables_all,
        )

        event_data[event_position_lookup[event_id_current]] = data_window_final
        event_data[findfirst(events.ids .== event_id_current)]
        counter += 1
      end
    end
  end

  return event_data
end

function intersect_where(x::AbstractVector, y::AbstractVector)
  ## Return the positions of x in y.
  findall(in(y), x)
end

struct Event_Estimate
  data::Data_Window
  success::Bool
  thinvar::BitVector
  cum_periods::Vector{Int64}
  ## Model parameters:
  parameter_names::Vector{String}
  parameter_values::Vector{Float64}
  parameter_p_values::Vector{Float64}
  ## Stuff for the tests:
  L1::Int64
  k::Int64
  sigma_sqrd::Float64
  ## NOTE(florian): Correction term to account for forecast
  ## error. Used to calculate SAR. Meitioned in patell1976, this
  ## form taken from kolari2010 (21.05.2023, 11:34)
  adjustment::Vector{Float64}
  r::Vector{Float64}
  er::Vector{Float64}
  ar::Vector{Float64}
end

@kwdef struct Data_Hypothesis_Tests
  id_event::Vector{String}
  R::Matrix{Float64}
  ER::Matrix{Float64}
  AR::Matrix{Float64}
  SAR::Matrix{Float64}
  STDF::Matrix{Float64}
  DATES::Matrix{<:Union{Nothing,Date}}
  THINVAR::Matrix{Bool}
  CUM_PERIODS::Matrix{Bool}
  sigma_sqrd::Vector{Float64}
  k::Vector{Int}
  L1::Vector{Int}
  data_timeline::DataFrame
end
