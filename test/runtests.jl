using Test
using EventStudy

using DataFrames
using CSV

function get_field(x, g::String, from::Int64, to::Int64, field::String)
  rows = eachrow(x)
  idx_abs = findfirst(a -> (a.id_group == g) && (a.idx_from == from) && (a.idx_to == to), rows)
  y = getproperty(rows[idx_abs], field)

  return y
end

function get_field(x, g::String, idx::Int64, field::String)
  rows = eachrow(x)
  idx_abs = findfirst(a -> (a.id_group == g) && (a.idx == idx), rows)
  y = getproperty(rows[idx_abs], field)

  return y
end

include("Testcase_Clean/tests.jl")
