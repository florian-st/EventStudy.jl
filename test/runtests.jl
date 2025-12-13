using Test
using EventStudy

using DataFrames
using CSV

function get_field(x, g::String, from::Int64, to::Int64, d::Int64, field::Symbol)
  rows = eachrow(x)
  idx_abs = findfirst(a -> (a.id_group == g) && (a.idx_from == from) && (a.idx_to == to), rows)
  y = getproperty(rows[idx_abs], field)

  return (y isa AbstractFloat) ? trunc(y; digits=d) : y
end

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Basic complete Dataset
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Basic data:
df_events = CSV.read("test/data/events.csv", DataFrame)
data_events_complete = Events(df_events, "id_event", "date", "id_firm", "id_market")
data_markets_complete = Data_Markets(CSV.read("test/data/markets.csv", DataFrame), "id_market", "date", String["ret_m"])
data_firms_complete = Data_Firms(CSV.read("test/data/firms.csv", DataFrame), "id_firm", "date", String["ret"])

## Build timeline:
windows_event = [(-2, 2)]
windows_estimation = [(-110, -100), (-99, -10)]
windows_post = [(5, 10)]
timeline = Timeline(windows_estimation, windows_event, windows_post)

## Construct Window Data:
shift = 0
expected_return_models = map(_ -> Model_Expected_Returns(:ret, Symbol[:ret_m]), data_events_complete.ids)

variables_market = unique(reduce(vcat, EventStudy.variables_get_market.(expected_return_models)))
variables_firm = unique(reduce(vcat, EventStudy.variables_get_firm.(expected_return_models)))

event_window_data = Data_Window(
  timeline,
  data_events_complete,
  data_firms_complete,
  data_markets_complete,
  variables_firm,
  variables_market,
  shift,
)

## Estimation:
event_estimates = event_estimate.(event_window_data, expected_return_models, Ref(timeline))

## Hypothesis testing:
idx_estimation_success = getproperty.(event_estimates, :success)
idx_estimate_testable = trues(length(event_estimates))
idx_included_overall = idx_estimation_success .* idx_estimate_testable

events_testable = event_estimates[idx_included_overall]
hypothesis_data = event_hypothesis_data_create(events_testable, timeline, windows_event)

ids_group = String.(innerjoin(DataFrame(id_event=hypothesis_data.id_event), select(transform(df_events, :id_event => ByRow(string); renamecols=false), [:id_event, :id_group]), on=:id_event).id_group)
df_tests = hypothesis_tests_run(hypothesis_data, ids_group, windows_event, timeline)


@testset "Complete Dataset Basics" begin
  @test get_field(df_tests.results_caar, "G2", -2, 2, 6, :caar) == 0.047489
  @test get_field(df_tests.results_caar, "G2", -2, 2, 6, :N) == 9
end
