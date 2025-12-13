module EventStudy

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Dependencies
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
using Dates
using PooledArrays
using Statistics
using NaNStatistics
using StatsBase
using LinearAlgebra
using Distributions
using GLM

## TODO: Change this to Tables.jl eventually (13.12.2025, 10:28)
using DataFrames


## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Exports
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
export Events, Data_Firms, Data_Markets, Timeline, Data_Window, Data_Hypothesis_Tests, Model_Expected_Returns
export event_estimate, event_hypothesis_data_create, hypothesis_tests_run
export event_study_run


## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Top Level Function
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function event_study_run(data_events, data_firms, data_markets, expected_return_models;
  groups::Vector{<:AbstractString}=fill("All", length(data_events.ids)),
  windows_event::Vector{Tuple{Int,Int}}=[(-5, 5), (0, 1)],
  windows_estimation::Vector{Tuple{Int,Int}}=[(-120, -100), (-99, -6)],
  windows_post::Vector{Tuple{Int,Int}}=[(6, 10)],
  shift::Int=0,
  f_validation::Function=(x -> true)
)

  ## Input checks
  ## ...
  ## ...
  ## ...

  ## Estimate:
  timeline = Timeline(windows_estimation, windows_event, windows_post)
  variables_market = unique(reduce(vcat, EventStudy.variables_get_market.(expected_return_models)))
  variables_firm = unique(reduce(vcat, EventStudy.variables_get_firm.(expected_return_models)))
  event_window_data = Data_Window(timeline, data_events, data_firms, data_markets, variables_firm, variables_market, shift)

  event_estimates = event_estimate.(event_window_data, expected_return_models, Ref(timeline))

  ## Hypothesis testing:
  idx_estimation_success = getproperty.(event_estimates, :success)
  idx_estimate_testable = f_validation.(event_estimates)
  idx_included_overall = idx_estimation_success .* idx_estimate_testable

  events_testable = event_estimates[idx_included_overall]
  hypothesis_data = event_hypothesis_data_create(events_testable, timeline, windows_event)
  hypothesis_tests = hypothesis_tests_run(hypothesis_data, groups, windows_event, timeline)

  ## Collect data to return:
  study = (
    results_aar = hypothesis_tests.results_aar,
    results_caar = hypothesis_tests.results_caar,
  )

  return study
end

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Includes
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
include("types.jl")
include("estimation.jl")
include("hypothesis_testing.jl")


## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Module End
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
end
