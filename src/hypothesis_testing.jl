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

    ## Export AR/CAR Data (for Carmodels)
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


## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Running Hypothesis Tests
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function hypothesis_tests_run(
    data::Data_Hypothesis_Tests,
    groups::Vector{String},
    windows_event::Vector{Tuple{Int64,Int64}},
    timeline::Timeline
    # groups_all::Vector{<:AbstractString},
    # window_event_largest::Tuple{Int64,Int64},
    # window_data_template,
)

    n_days, n_events = size(data.AR)
    timeline_absolute_all = eachindex(1:n_days)
    timeline_relative_all = vcat(timeline.estimation_relative, timeline.event_relative, timeline.post_relative)

    ## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ## Prep
    ## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    AAR_EXCLUDE = fill(false, n_days, n_events)
    CAR_EXCLUDE = fill(false, n_days, n_events)
    for c in 1:n_events
        for r in 1:(n_days-1)
            if isnan(data.AR[r, c])
                CAR_EXCLUDE[r, c] = true
                AAR_EXCLUDE[[r, r + 1], c] .= true
            end
        end
    end
    CAR_EXCLUDE[n_days, :] .= isnan.(data.AR[n_days, :])
    AAR_EXCLUDE[n_days, :] .= isnan.(data.AR[n_days, :])

    CAR_INCLUDE = .!CAR_EXCLUDE
    AAR_INCLUDE = .!AAR_EXCLUDE

    ## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ## AR Tests
    ## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    groups_unique = unique(groups)
    window_event_largest = window_create_largest(windows_event)

    aar_idx = collect(window_event_largest[1]:window_event_largest[2])
    df_aar_tmp = Vector{DataFrame}(undef, length(groups_unique))
    df_caar_tmp = Vector{DataFrame}(undef, length(groups_unique))
    ## TODO(florian): Find rows of each aar idx and caar window. Move
    ## this to window template construction... (14.05.2024, 08:21)
    idx_rel_event = timeline_relative_all[timeline.event_absolute]
    idx_windows_event = Vector{BitVector}(undef, length(windows_event))
    for (j, w) in enumerate(windows_event)
        idx = collect(w[1]:w[2])
        idx_windows_event[j] = idx_rel_event .∈ Ref(idx)
    end

    for (i, g) in enumerate(groups_unique)
        columns_group = findall(groups .== g)

        ## Base stuff:
        AR_event = data.AR[timeline.event_absolute, columns_group]
        ER_event = data.ER[timeline.event_absolute, columns_group]
        R_event = data.R[timeline.event_absolute, columns_group]
        AR_estimation = data.AR[timeline.estimation_absolute, columns_group]
        SAR_event = data.SAR[timeline.event_absolute, columns_group]
        SAR_estimation = data.SAR[timeline.estimation_absolute, columns_group]
        AAR_INCLUDE_event = AAR_INCLUDE[timeline.event_absolute, columns_group]
        CAR_INCLUDE_event = CAR_INCLUDE[timeline.event_absolute, columns_group]

        sigma_sqrd_group = data.sigma_sqrd[columns_group]
        k_group = data.k[columns_group]
        L1_group = data.L1[columns_group]

        ## NOTE(florian): Kolari adjustment: All correlations of abnormal
        ## returns in the estimation window: (02.10.2022, 18:42)
        kolari_adj = kolari_adjustement(SAR_estimation)

        ## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        ## AAR Results
        ## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

        ## AAR value:
        ## NOTE(florian): The number of returns to divide by is
        ## determined by Mayers blah blah procedure. (12.05.2024,
        ## 18:31)
        N_aar = fill(0, length(aar_idx))
        AAR_event = fill(NaN, length(aar_idx))
        for j in eachindex(aar_idx)
            idx_include = AAR_INCLUDE_event[j, :]
            N_aar[j] = sum(idx_include)
            AAR_event[j] = mean(AR_event[j, idx_include])
        end

        ## TODO(florian): Why is this not used everywhere??? (05.06.2023, 18:38)
        t_dof_n = L1_group .- k_group .- 1
        t_dof = maximum(L1_group) - maximum(k_group) - 1

        ## Patell test:
        sum_event_sar = nansum(SAR_event; dim=2)
        scl = 1 / sqrt(sum((L1_group .- k_group .- 1) ./ (L1_group .- k_group .- 3)))
        patell_aar = scl .* sum_event_sar
        patell_aar_p = 2 .* cdf.(Normal(0, 1), abs.(patell_aar) .* -1)
        patell_kolari_aar = patell_aar .* kolari_adj
        patell_kolari_aar_p = 2 .* cdf.(Normal(0, 1), abs.(patell_kolari_aar) .* -1)

        ## Boehmer test:
        boehmer_aar = (sum_event_sar ./ N_aar) ./ sqrt.((1 ./ N_aar) .* nanvar(SAR_event; dim=2))
        boehmer_aar_p = 2 .* cdf.(TDist(t_dof), abs.(boehmer_aar) .* -1)
        boehmer_kolari_aar = boehmer_aar .* kolari_adj
        boehmer_kolari_aar_p = 2 .* cdf.(Normal(0, 1), abs.(boehmer_kolari_aar) .* -1)

        ## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        ## CAAR Results
        ## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        N_caar = fill(0, length(windows_event))
        CAAR_event = fill(NaN, length(windows_event))
        N_caar = fill(0, length(windows_event))

        patell_caar_windows = fill(0.0, length(windows_event))
        patell_caar_p_windows = fill(0.0, length(windows_event))
        patell_caar_kolari_windows = fill(0.0, length(windows_event))
        patell_caar_kolari_p_windows = fill(0.0, length(windows_event))
        boehmer_caar_windows = fill(0.0, length(windows_event))
        boehmer_caar_p_windows = fill(0.0, length(windows_event))
        boehmer_caar_kolari_windows = fill(0.0, length(windows_event))
        boehmer_caar_kolari_p_windows = fill(0.0, length(windows_event))
        grankt_caar_kolari_windows = fill(0.0, length(windows_event))
        grankt_caar_kolari_p_windows = fill(0.0, length(windows_event))
        for (j, w) in enumerate(windows_event)
            idx = idx_windows_event[j]
            AR_relevent = AR_event[idx, :]
            AR_relevant_include = CAR_INCLUDE_event[idx, :]

            n_cols = size(AR_relevent, 2)
            col_sums = fill(0.0, n_cols)
            tmp_n = fill(0, n_cols)
            for c in 1:n_cols
                idx_incl = AR_relevant_include[:, c]
                col_sums[c] = sum(AR_relevent[idx_incl, c])
            end

            any_data = any.(eachcol(AR_relevant_include))
            N_caar[j] = sum(any_data)
            CAAR_event[j] = mean(col_sums[any_data])


            idx_cols = any.(eachcol(CAR_INCLUDE_event[idx, :]))
            SAR_event_relevant = SAR_event[idx, idx_cols]

            ## Patell test:
            L = cumsum(CAR_INCLUDE_event[idx, idx_cols]; dims=1)
            WiL = nansum(SAR_event_relevant ./ sqrt.(L); dim=1)

            patell_caar = sum(WiL) ./ (1 / scl)
            patell_caar_kolari = patell_caar * kolari_adj

            patell_caar_p = 2 * cdf(Normal(0, 1), abs(patell_caar) * -1)
            patell_caar_kolari_p = 2 * cdf(Normal(0, 1), abs(patell_caar_kolari) * -1)

            patell_caar_windows[j] = patell_caar
            patell_caar_p_windows[j] = patell_caar_p
            patell_caar_kolari_windows[j] = patell_caar_kolari
            patell_caar_kolari_p_windows[j] = patell_caar_kolari_p

            ## Boehmer test:
            N_L = sum.(eachrow(CAR_INCLUDE_event[idx, idx_cols]))

            ## NOTE(florian): WORKS!!!! But I think this is not quite right in evenstudy2, dimensions dont match... (29.07.2024, 22:16)
            ## NOTE(florian): I am not sure why this works, but it
            ## does. Eventstudy2 calculates multiple values here, but
            ## then takes the last as the test statistic. Which is the
            ## one calculated here. (30.07.2024, 09:03)
            WiL_caar = nancumsum(SAR_event_relevant ./ sqrt.(L); dims=1)
            WiL_caar[.!CAR_INCLUDE_event[idx, idx_cols]] .= NaN
            boehmer_caar = last((nansum(WiL_caar; dim=2) ./ N_L) ./ sqrt.((1 ./ N_L) .* nanvar.(eachcol(WiL_caar'))))
            boehmer_caar_p = 2 .* cdf.(TDist(t_dof), abs.(boehmer_caar) .* -1)
            boehmer_caar_kolari = boehmer_caar * kolari_adj
            boehmer_caar_kolari_p = 2 .* cdf.(TDist(t_dof), abs.(boehmer_caar_kolari) .* -1)

            ## NOTE(florian): Is equivalent to the above thing... (30.07.2024, 09:05)
            # boehmer_caar = last((sum(WiL) ./ N_L) ./ sqrt.((1 ./ N_L) .* nanvar(WiL)))
            # boehmer_caar_p = 2 .* cdf.(TDist(t_dof), abs.(boehmer_caar) .* -1)
            boehmer_caar_windows[j] = boehmer_caar
            boehmer_caar_p_windows[j] = boehmer_caar_p
            boehmer_caar_kolari_windows[j] = boehmer_caar_kolari
            boehmer_caar_kolari_p_windows[j] = boehmer_caar_kolari_p


            ## GRANKT nonparametric:
            # ## TODO(florian): Parts are just translation from eventstudytools, do not know what happens here all the time. (21.05.2023, 17:04)
            SCARstari = (WiL_caar .* kolari_adj) ./ sqrt.(((1 ./ N_L) .* nanvar(WiL_caar; dim=2)))
            SCARstariLASTROW = SCARstari[end:end, :]
            SARit = AR_estimation ./ sqrt.(nansum(AR_estimation .^ 2; dim=1) ./ t_dof_n)'
            ## TODO(florian): Does not properly work with completely
            ## missing events yet I think. Look at stata code (08.09.2024, 16:11)
            ARTOTALGRANK = vcat(SARit[:, idx_cols], SCARstariLASTROW)
            ARTOTALRANKGRANK = float.(reduce(hcat, StatsBase.ordinalrank.(eachslice(ARTOTALGRANK, dims=2))))
            ARTOTALRANKGRANK[isnan.(ARTOTALGRANK)] .= NaN
            Uit = (ARTOTALRANKGRANK ./ (data.L1[columns_group][idx_cols] .+ 2)') .- 0.5
            U_tbar = nanmean(Uit; dim=2)
            T_GRANK = sum(.!isnan.(U_tbar)) - 1
            n_denom = sum(.!isnan.(SCARstariLASTROW))
            n_nom = sum(.!isnan.(Uit[1:(end-1), :]); dims=2)
            S_Ubar = sqrt((1 / T_GRANK) * nansum((n_nom ./ n_denom) .* U_tbar[1:(end-1)] .^ 2))
            ZGRANK = last(U_tbar ./ S_Ubar)
            tGRANK = try
                ZGRANK * sqrt((T_GRANK - 2) / (T_GRANK - 1 - ZGRANK .^ 2))
            catch
                @warn "GRANKT failed!"
                1
            end
            # ## TODO(florian): I do not understand why eventstudytools does this step. Basically, it copies t_GRANK into an AAR format. (06.06.2023, 08:28)
            # # NCAAREGRANKT = tGRANK .* rowsum((SCARstari :+ 100) :/ (SCARstari :+ 100)) :/ rowsum((SCARstari :+ 100) :/ (SCARstari :+ 100))
            tGRANK_p = 2 .* cdf.(TDist(T_GRANK - 2), abs.(tGRANK) .* -1)

            grankt_caar_kolari_windows[j] = tGRANK
            grankt_caar_kolari_p_windows[j] = tGRANK_p
        end

        ## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        ## Collect results
        ## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        df_aar_current = DataFrame(
            id_group=g,
            idx=aar_idx,
            N=N_aar,
            aar=AAR_event,
            patell=patell_aar,
            patell_p=patell_aar_p,
            patell_kolari=patell_kolari_aar,
            patell_kolari_p=patell_kolari_aar_p,
            boehmer=boehmer_aar,
            boehmer_p=boehmer_aar_p,
            boehmer_kolari=boehmer_kolari_aar,
            boehmer_kolari_p=boehmer_kolari_aar_p
        )
        df_aar_tmp[i] = df_aar_current

        df_caar_current = DataFrame(
            id_group=g,
            idx_from=first.(windows_event),
            idx_to=last.(windows_event),
            N=N_caar,
            caar=CAAR_event,
            patell=patell_caar_windows,
            patell_p=patell_caar_p_windows,
            patell_kolari=patell_caar_kolari_windows,
            patell_kolari_p=patell_caar_kolari_p_windows,
            boehmer=boehmer_caar_windows,
            boehmer_p=boehmer_caar_p_windows,
            boehmer_kolari=boehmer_caar_kolari_windows,
            boehmer_kolari_p=boehmer_caar_kolari_p_windows,
            grankt=grankt_caar_kolari_windows,
            grankt_p=grankt_caar_kolari_p_windows
        )
        df_caar_tmp[i] = df_caar_current
    end
    results_aar = reduce(vcat, df_aar_tmp)
    results_caar = reduce(vcat, df_caar_tmp)

    return (
        results_aar=results_aar,
        results_caar=results_caar,
    )
end
