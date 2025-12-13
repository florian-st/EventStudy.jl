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
export Events, Data_Firms, Data_Markets, Timeline, Data_Window
export Model_Expected_Returns


## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Includes
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
include("types.jl")


## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Module End
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
end
