## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Construct Data
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function event_hypothesis_data_create(estimates_testable::Vector{Event_Estimate}, timeline::Timeline, windows_event::Vector{Tuple{Int,Int}})
  n_events = length(estimates_testable)
  n_days = length(timeline.relative_to_absolute)

  ## Event and time dimension
  R = fill(NaN, n_days, n_events)
  ER = fill(NaN, n_days, n_events)
  AR = fill(NaN, n_days, n_events)
  SAR = fill(NaN, n_days, n_events)
  STDF = fill(NaN, n_days, n_events)
  DATES = Matrix{Union{Nothing,Date}}(nothing, n_days, n_events)

  THINVAR = fill(false, n_days, n_events)
  CUM_PERIODS = fill(0, n_days, n_events)

  ## Event dimension:
  sigma_sqrd = Vector{Float64}(undef, n_events)
  k = Vector{Int64}(undef, n_events)
  L1 = Vector{Int64}(undef, n_events)
  event_ids = Vector{String}(undef, n_events)

  for (i, e) in enumerate(estimates_testable)
    ## TODO(florian): I do this exacly like eventstudy2, though I'm
    ## not sure why σ² is used three times, once when building
    ## :fe_event and then here twice (28.06.2022, 09:18)
    ## NOTE(florian): Using this method yields very slightly different
    ## results than using the version that is in the kolari as well as patell paper
    ## paper, which would just be: e.ar ./ stdf  (28.06.2022, 10:37)
    σ = sqrt(e.sigma_sqrd)
    stdf = σ .* sqrt.(e.adjustment .+ 1)
    sar = e.ar ./ σ ./ sqrt.(stdf ./ σ)

    AR[:, i] = e.ar
    ER[:, i] = e.er
    R[:, i] = e.r
    DATES[:, i] = e.data.date_all
    k[i] = e.k
    L1[i] = e.L1
    sigma_sqrd[i] = e.sigma_sqrd
    STDF[:, i] = stdf
    SAR[:, i] = sar

    THINVAR[:, i] = e.thinvar
    CUM_PERIODS[:, i] = e.cum_periods

    event_ids[i] = e.data.id
  end

  ## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  ## Export AR/CAR Data (for Carmodels)
  ## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  idx_rel = vcat(timeline.estimation_relative, timeline.event_relative, timeline.post_relative)
  n_total = n_days * n_events
  idx_type = vcat(fill("estimation", length(timeline.estimation_relative)), fill("event", length(timeline.event_relative)), fill("post", length(timeline.post_relative)))

  ## Initialize data:
  df_ar_data = DataFrame(
    id_event=Vector{String}(undef, n_total),
    date=Vector{Union{Nothing,Date}}(nothing, n_total),
    rel=Vector{Int64}(undef, n_total),
    periods=Vector{String}(undef, n_total),
    ar=Vector{Float64}(undef, n_total)
  )

  ## Fill data:
  idx_start = 1
  for i in 1:n_events
    r = idx_start:(idx_start+n_days-1)

    ## Add data:
    df_ar_data.rel[r] = idx_rel
    df_ar_data.periods[r] = idx_type
    df_ar_data.date[r] = DATES[:, i]
    df_ar_data.id_event[r] .= event_ids[i]
    df_ar_data.ar[r] = AR[:, i]

    idx_start += n_days
  end
  transform!(df_ar_data, [:id_event] .=> PooledArray; renamecols=false)

  ## Add car columns:
  for w in windows_event
    car_data = car_calculate(df_ar_data.ar, w[1], w[2])
    ## TODO(florian): Make into parameter (28.08.2024, 10:04)
    # car_label = string("car_", w[1], "_", w[2])
    car_label = string("car_", (w[1] < 0 ? string("m", abs(w[1])) : string("p", w[1])), w[2] < 0 ? string("m", abs(w[2])) : string("p", w[2]))

    insertcols!(df_ar_data, ncol(df_ar_data) + 1, car_label => car_data)
  end

  ## Collect data:
  data_testable = Data_Hypothesis_Tests(
    id_event=event_ids,
    R=R,
    ER=ER,
    AR=AR,
    SAR=SAR,
    STDF=STDF,
    DATES=DATES,
    THINVAR=THINVAR,
    CUM_PERIODS=CUM_PERIODS,
    sigma_sqrd=sigma_sqrd,
    k=k,
    L1=L1,
    data_timeline=df_ar_data
  )

  return data_testable
end

function car_calculate(x::AbstractVector{<:Number}, car_start::Int64, car_end::Int64)
  @assert car_start <= car_end

  y = fill(NaN, length(x))
  back = (car_start < 0) ? abs(car_start) : 0
  front = (car_end > 0) ? car_end : 0

  idx_start = 1 + back
  idx_end = length(x) - front

  for i in idx_start:idx_end
    y[i] = nansum(x[(i+car_start):(i+car_end)])
  end

  return y
end

