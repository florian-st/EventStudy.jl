## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Run Study
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Basic data:
df_events_1 = CSV.read("test/Testcase_Clean/events_group_1.csv", DataFrame)
df_events_2 = CSV.read("test/Testcase_Clean/events_group_2.csv", DataFrame)

df_events = vcat(df_events_1, df_events_2)
ids_group = String.(vcat(df_events_1.id_group, df_events_2.id_group))


data_events_complete = Events(df_events, "id_event", "date", "id_firm", "id_market")
data_markets_complete = Data_Markets(CSV.read("test/Testcase_Clean/markets.csv", DataFrame), "id_market", "date", String["ret_m"])
data_firms_complete = Data_Firms(CSV.read("test/Testcase_Clean/firms.csv", DataFrame), "id_firm", "date", String["ret"])

## Build timeline:
windows_event = [(-5, 5), (0, 1)]
windows_estimation = [(-120, -100), (-99, -6)]
windows_post = [(6, 10)]
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

study = event_study_run(data_events_complete, data_firms_complete, data_markets_complete, expected_return_models;
    groups=ids_group,
    windows_event=windows_event,
    windows_estimation=windows_estimation,
    windows_post=windows_post,
    shift=shift,
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
