using Test
using EventStudy

using DataFrames
using CSV

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Basic complete Dataset
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
data_events_complete = Events(CSV.read("test/data/events.csv", DataFrame), "id_event", "date", "id_firm", "id_market")
data_markets_complete = Data_Markets(CSV.read("test/data/markets.csv", DataFrame), "id_market", "date", String["ret_m"])
data_firms_complete = Data_Firms(CSV.read("test/data/firms.csv", DataFrame), "id_firm", "date", String["ret"])
