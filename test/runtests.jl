using Test
using EventStudy

using DataFrames
using CSV

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Basic complete Dataset
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Basic data:
data_events_complete = Events(CSV.read("test/data/events.csv", DataFrame), "id_event", "date", "id_firm", "id_market")
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

