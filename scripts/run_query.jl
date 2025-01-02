include("../src/SimulationDatabase.jl")
using .SimulationDatabase

using DataFrames
using Plots

query = "SELECT * FROM simulations WHERE graph_type = 'grid' AND p = 0.2 AND m = 6144";
rows = run_query("simulations.db", query, ()); 
data = DataFrame(rows); 

ΔE = (vcat(data.E...) - vcat(data.F_R...)); 

histogram(ΔE)
