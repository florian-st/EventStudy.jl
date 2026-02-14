## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Run Study
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

## Raw data as a DataFrame:
df_events  = CSV.read("test/Testcase_Clean/events.csv", DataFrame)
df_firms   = CSV.read("test/Testcase_Clean/markets.csv", DataFrame)
df_markets = CSV.read("test/Testcase_Clean/firms.csv", DataFrame)

## Prepare study by transforming the DataFrames into the corresponding
## data structs. The cols_other argument is used to specify all
## columns that are needed for any normal return model used:
data_events = Events(df_events;
    col_id      = "id_event",
    col_date    = "date",
    col_firms   = "id_firm",
    col_markets = "id_market"
)

data_markets = Data_Markets(df_firms;
    col_ids    = "id_market",
    col_dates  = "date",
    cols_other = String["ret_m"]
)

data_firms = Data_Firms(df_markets;
    col_ids    = "id_firm",
    col_dates  = "date",
    cols_other = String["ret"]
)

## Set parameters:
windows_event = [(-5, 5), (0, 1)]
windows_estimation = [(-120, -100), (-99, -6)]
windows_post = [(6, 10)]
shift = 0

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

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Tests:
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
@testset "Clean Dataset" begin
    ## AAR N
    @test get_field(study.results_aar, "G1", -5, "N") == 16
    @test get_field(study.results_aar, "G1", -4, "N") == 16
    @test get_field(study.results_aar, "G1", -3, "N") == 16
    @test get_field(study.results_aar, "G1", -2, "N") == 16
    @test get_field(study.results_aar, "G1", -1, "N") == 16
    @test get_field(study.results_aar, "G1", 0, "N") == 16
    @test get_field(study.results_aar, "G1", 1, "N") == 16
    @test get_field(study.results_aar, "G1", 2, "N") == 16
    @test get_field(study.results_aar, "G1", 3, "N") == 16
    @test get_field(study.results_aar, "G1", 4, "N") == 16
    @test get_field(study.results_aar, "G1", 5, "N") == 16

    @test get_field(study.results_aar, "G2", -5, "N") == 10
    @test get_field(study.results_aar, "G2", -4, "N") == 10
    @test get_field(study.results_aar, "G2", -3, "N") == 10
    @test get_field(study.results_aar, "G2", -2, "N") == 10
    @test get_field(study.results_aar, "G2", -1, "N") == 10
    @test get_field(study.results_aar, "G2", 0, "N") == 10
    @test get_field(study.results_aar, "G2", 1, "N") == 10
    @test get_field(study.results_aar, "G2", 2, "N") == 10
    @test get_field(study.results_aar, "G2", 3, "N") == 10
    @test get_field(study.results_aar, "G2", 4, "N") == 10
    @test get_field(study.results_aar, "G2", 5, "N") == 10

    ## AAR Value
    @test round(get_field(study.results_aar, "G1", -4, "aar"); digits=7) == -0.0001844
    @test round(get_field(study.results_aar, "G1", -3, "aar"); digits=7) == 0.0041964
    @test round(get_field(study.results_aar, "G1", -2, "aar"); digits=6) == -0.002487
    @test round(get_field(study.results_aar, "G1", -1, "aar"); digits=7) == -0.0092609
    @test round(get_field(study.results_aar, "G1", -0, "aar"); digits=7) == -0.0046859
    @test round(get_field(study.results_aar, "G1", 1, "aar"); digits=7) == 0.0619481
    @test round(get_field(study.results_aar, "G1", 2, "aar"); digits=7) == 0.0098247
    @test round(get_field(study.results_aar, "G1", 3, "aar"); digits=7) == 0.0127586
    @test round(get_field(study.results_aar, "G1", 4, "aar"); digits=7) == 0.0085555
    @test round(get_field(study.results_aar, "G1", 5, "aar"); digits=7) == 0.0293382

    @test round(get_field(study.results_aar, "G2", -5, "aar"); digits=7) == -0.0007243
    @test round(get_field(study.results_aar, "G2", -4, "aar"); digits=6) == -0.000981
    @test round(get_field(study.results_aar, "G2", -3, "aar"); digits=7) == -0.0013198
    @test round(get_field(study.results_aar, "G2", -2, "aar"); digits=7) == 0.0095689
    @test round(get_field(study.results_aar, "G2", -1, "aar"); digits=7) == -0.0052336
    @test round(get_field(study.results_aar, "G2", -0, "aar"); digits=7) == -0.0099132
    @test round(get_field(study.results_aar, "G2", 1, "aar"); digits=7) == 0.0688317
    @test round(get_field(study.results_aar, "G2", 2, "aar"); digits=7) == -0.0026087
    @test round(get_field(study.results_aar, "G2", 3, "aar"); digits=7) == 0.0167726
    @test round(get_field(study.results_aar, "G2", 4, "aar"); digits=7) == -0.0088213
    @test round(get_field(study.results_aar, "G2", 5, "aar"); digits=7) == 0.0203204

    ## CAAR N
    @test get_field(study.results_caar, "G1", -5, 5, "N") == 16
    @test get_field(study.results_caar, "G2", -5, 5, "N") == 10
    @test get_field(study.results_caar, "G1", 0, 1, "N") == 16
    @test get_field(study.results_caar, "G2", 0, 1, "N") == 10

    ## CAAR values
    @test round(get_field(study.results_caar, "G1", -5, 5, "caar"); digits=7) == 0.1100127
    @test round(get_field(study.results_caar, "G2", -5, 5, "caar"); digits=7) == 0.0858916
    @test round(get_field(study.results_caar, "G1", 0, 1, "caar"); digits=7) == 0.0572621
    @test round(get_field(study.results_caar, "G2", 0, 1, "caar"); digits=7) == 0.0589185

    ## CAAR KP:
    @test round(get_field(study.results_caar, "G1", 0, 1, "boehmer_kolari"); digits=6) == 1.770422
    @test round(get_field(study.results_caar, "G1", 0, 1, "boehmer_kolari_p"); digits=6) == 0.079354

    ## CAAR GRANK
    @test round(get_field(study.results_caar, "G1", 0, 1, "grankt"); digits=6) == 4.151076
    @test round(get_field(study.results_caar, "G1", 0, 1, "grankt_p"); digits=7) == 0.0000644
end
