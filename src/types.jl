## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Basic Data
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
struct Events
  ids::Vector{String}
  dates::Vector{Date}
  firms::PooledVector
  markets::PooledVector
end

struct Data_Firms
  ids::PooledVector
  dates::Vector{Date}
  columns::Vector{Symbol}
  data::Matrix{Float64}
end

struct Data_Markets
  ids::PooledVector
  dates::Vector{Date}
  columns::Vector{Symbol}
  data::Matrix{Float64}
end

function Events(df::DataFrame, col_id::String, col_date::String, col_firms::String, col_markets::String)
  @assert allunique(df[!, col_id])

  events = Events(
    string.(df[!, col_id]),
    Date.(df[!, col_date]),
    PooledArray(df[!, col_firms]),
    PooledArray(df[!, col_markets]),
  )

  return events
end

function Data_Markets(df::DataFrame, col_ids::String, col_dates::String, cols_other::Vector{String})

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

function Data_Firms(df::DataFrame, col_ids::String, col_dates::String, cols_other::Vector{String})

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

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Timeline
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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

