## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Basic Data
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Basic data:
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
