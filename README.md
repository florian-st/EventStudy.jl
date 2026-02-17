# EventStudy.jl

This package can be used to run Event Studies as outlined in [(McKinlay, 1997)](https://www.jstor.org/stable/2729691#:~:text=Using%20financial%20market%20data%2C%20an,reflected%20immediately%20in%20security%20prices.).

It has the following advantages over existing solutions:
- Estimates normal returns using an arbitrary regression model
- Runs fast and reliable for large samples (10000 events and more), including the [(Kolari, 2010)](https://academic.oup.com/rfs/article-abstract/23/11/3996/1605665?redirectedFrom=fulltext) and [(Kolari, 2011)](https://www.sciencedirect.com/science/article/abs/pii/S0927539811000624) test statistics.


# Example
This is a small example to demonstrate how the package works. The data is in the test directory!

```julia
using EventStudy
using DataFrames
using CSV

## Raw data as a DataFrame:
df_events  = CSV.read("test/Testcase_Clean/events.csv", DataFrame)
df_firms   = CSV.read("test/Testcase_Clean/firms.csv", DataFrame)
df_markets = CSV.read("test/Testcase_Clean/markets.csv", DataFrame)

## Prepare study by transforming the DataFrames into the corresponding
## data structs. The cols_other argument is used to specify all
## columns that are needed for any normal return model used:
data_events = Events(df_events;
    col_id      = "id_event",
    col_date    = "date",
    col_firms   = "id_firm",
    col_markets = "id_market"
)

data_markets = Data_Markets(df_markets;
    col_ids    = "id_market",
    col_dates  = "date",
    cols_other = String["ret_m"]
)

data_firms = Data_Firms(df_firms;
    col_ids    = "id_firm",
    col_dates  = "date",
    cols_other = String["ret"]
)

## Set parameters:
windows_event      = [(-5, 5), (0, 1)]
windows_estimation = [(-120, -100), (-99, -6)]
windows_post       = [(6, 10)]
shift              = 0

## Set estimation model. Each event can be estimated using a separate
## model. Here we just use a regular market model for all events:
expected_return_models = map(_ -> Model_Expected_Returns(:ret, Symbol[:ret_m]), data_events.ids)

## Run the study. It returns a Tuple with (cumulative) abnormal return
## estimates and AAR/CAAR significance tests.
study = event_study_run(data_events, data_firms, data_markets, expected_return_models;
    groups             = String.(df_events.id_group),
    windows_event      = windows_event,
    windows_estimation = windows_estimation,
    windows_post       = windows_post,
    shift              = shift,
)
```
