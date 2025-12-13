## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Basic Estimation
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function event_estimate(data::Data_Window, model::Model_Expected_Returns, timeline::Timeline)
  ## Indices:
  vars_market = variables_get_market(model)
  vars_firm = variables_get_firm(model)

  idx_vars_market = map(x -> findfirst(data.data_col_names .== x), vars_market)
  idx_var_return = findfirst(data.data_col_names .== model.dependent)
  idx_vars_all = vcat(idx_vars_market, idx_var_return)

  parameter_names = vcat("intercept", string.(model.independent))

  ## Datasets:
  ## TODO(florian): Make this adjustment in eventstudy2 into a
  ## parameter... (28.07.2024, 19:03)
  firm_return_original = copy(data.data[:, idx_var_return])
  firm_return = @view data.data[:, idx_var_return]

  ## Cum periods:
  ## NOTE(florian): Not sure if thinvar actually ever needs to be
  ## stored. (28.07.2024, 19:06)
  cum_periods = fill(1, length(firm_return))
  thinvar = falses(length(firm_return))
  for i in 2:length(cum_periods)
    is_thinvar = isnan(firm_return[i-1]) && !isnan(firm_return[i])
    (is_thinvar || isnan(firm_return[i])) && isnan(firm_return[i-1]) && (cum_periods[i] = cum_periods[i] + cum_periods[i-1])
    thinvar[i] = is_thinvar
  end
  sqrt_periods = sqrt.(cum_periods)

  ## Market:
  for j in idx_vars_market
    for i in 2:length(cum_periods)
      if (cum_periods[i] > 1) && !isnan(data.data[i-1, j])
        data.data[i, j] = data.data[i, j] + data.data[i-1, j]
      end
    end
  end

  ## Cum version of y_all and intercept:
  data_matrix_est = data.data[timeline.estimation_absolute, idx_vars_all]
  sqrt_periods_est = sqrt_periods[timeline.estimation_absolute]
  data_est_row_available = matrix_rows_available(data_matrix_est)
  # X_all[:, 1] = 1 ./ sqrt_periods

  ## Estimation:
  L1 = sum(data_est_row_available)
  k = length(model.independent)

  y_est = data_matrix_est[data_est_row_available, idx_var_return]
  X_est = hcat(fill(1, length(y_est)), data_matrix_est[data_est_row_available, idx_vars_market])
  X_all = hcat(fill(1, length(timeline.relative_to_absolute)), data.data[:, idx_vars_market])

  ols, success, parameter_values, parameter_p_values = try
    ## TODO(florian): Not sure where exactly the square root division is needed... (28.07.2024, 19:57)
    mdl = GLM.lm(X_est ./ sqrt_periods_est[data_est_row_available], y_est ./ sqrt_periods_est[data_est_row_available])
    ## TODO(florian): Only return success when standard errors exist. Log (24.05.2023, 13:53)

    std_errors = coeftable(mdl).cols[2]
    parameter_values = coeftable(mdl).cols[1]
    parameter_p_values = coeftable(mdl).cols[4]

    success = all(isfinite.(std_errors))

    (mdl, success, parameter_values, parameter_p_values)
  catch e
    (nothing, false, nothing, nothing)
  end

  ## NOTE(florian): If estimation failed, return 'empty' struct (19.05.2023, 17:00)
  if !success
    empty_dummy = fill(NaN, length(firm_return))
    event_estimate = Event_Estimate(
      data,
      success,
      thinvar,
      cum_periods,
      parameter_names,
      fill(NaN, length(parameter_names)),
      fill(NaN, length(parameter_names)),
      L1,
      k,
      0.0,
      ## TODO(florian): empty_dummy not correct for adjustment... (01.09.2024, 09:30)
      empty_dummy,
      firm_return_original,
      empty_dummy,
      empty_dummy
    )

    return event_estimate
  end

  ## Adjustement factor for sar (kolari 2010 paper):
  ## TODO(florian): Try catch has to come here. (24.05.2023, 13:52)
  X_inv = inv(transpose(X_est) * X_est)
  adjustment_factor = calculate_adjustment_factor(X_all, X_inv)

  er = predict(ols, X_all)
  ar = firm_return_original .- er

  ar_est = @view ar[timeline.estimation_absolute]
  sigma_sqrd = (1 / (L1 - k - 1)) * sum(ar_est[data_est_row_available] .^ 2)

  ## Return estimated event:
  event_estimate = Event_Estimate(
    data,
    success,
    thinvar,
    cum_periods,
    parameter_names,
    parameter_values,
    parameter_p_values,
    L1,
    k,
    sigma_sqrd,
    adjustment_factor,
    firm_return_original,
    er,
    ar
  )

  return event_estimate
end

## TODO(florian): Make this faster (19.05.2023, 08:01)
function matrix_rows_available(M::AbstractMatrix)
  is_available = .!isnan.(M)
  rows_available = (x -> all(x .== 1)).(eachrow(is_available))

  return rows_available
end

function kolari_adjustement(X::Matrix{Float64})
  cor_mat = nancor(X)
  cor_pairs = cor_mat[tril!(trues(size(cor_mat)), -1)]

  ## TODO(florian): Log infinities here? (27.07.2022, 11:17)
  ρ̄ = mean(cor_pairs[isfinite.(cor_pairs)])

  n = size(X, 2)
  kolari_adj = sqrt(((1 - ρ̄) / (1 + (n - 1) * ρ̄)))

  return kolari_adj
end

## TODO(florian): How to do this most efficiently (23.05.2023, 17:17)
function calculate_adjustment_factor(x::Matrix{Float64}, X_inv::Matrix{Float64})
  (a -> transpose(Vector(a)) * X_inv * Vector(a)).(eachrow(x))
end
