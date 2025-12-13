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
export Events, Data_Firms, Data_Markets, Timeline, Data_Window, Data_Hypothesis_Tests
export Model_Expected_Returns
export event_estimate, event_hypothesis_data_create, hypothesis_tests_run


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
