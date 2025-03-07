"""
    This script runs simulations on the networks used in https://doi.org/10.1073/pnas.1110069108. 

    The networks are stored in the `mason_watts_graphs` folder.
"""

using Pkg
Pkg.activate(".")

using Revise

includet("../src/CustomGraphs.jl")
includet("../src/ResourceNetworks.jl")
includet("../src/Metrics.jl")

using .ResourceNetworks
using .CustomGraphs
using .Metrics

using Statistics, ProgressMeter
using UnPack
using DataFrames

# Network names in order
networks = [
    "min_avg_betweenness",
    "min_avg_clustering",
    "max_max_closeness",
    "max_var_constraint",
    "max_avg_clustering",
    "max_max_betweenness",
    "min_max_closeness",
    "max_avg_betweenness"
]

const l = 6

# Then create parameters dict using l's value
parameters = Dict{Symbol, Any}(
    :l => l,            
    :m => 64*l,       
    :R => 2,         
    :p_resource => 0.5 
)

function run_network_ensemble(network_name::String; parameters::Dict{Symbol, Any}, M::Int=1000)
    @unpack l, m, R, p_resource = parameters

    # Load the network
    adj_list, title, N = load_adjacency_list_txt("mason_watts_graphs/$network_name")
    G = adjacency_list_to_graph(adj_list)
    
    # Run M simulations
    results = zeros(M, 6)  # RMSE, MAE, MRE, MedRE, Frac_RE_lt_0.5, Avg_F_R
    
    @showprogress "simulating $network_name" for i in 1:M
        has_resource = [rand() < p_resource for _ in 1:N]
        RN = gen_ResourceNetwork(G, has_resource, m, l)
        propagate_w!(RN, R)
        calculate_E!(RN)
        
        F_R = count_resources_within_R(RN, R)
        
        results[i, 1] = rmse(F_R, RN.E)
        results[i, 2] = mae(F_R, RN.E)
        results[i, 3] = mre(F_R, RN.E)
        results[i, 4] = medre(F_R, RN.E)
        results[i, 5] = frac_re_lt(RN.E, F_R)  
        results[i, 6] = mean(F_R)               
    end
    
    # Return averages across all runs
    return mean(results, dims=1)[:]
end

# Run simulations for all networks
results_matrix = zeros(6, 8)  # 6 metrics × 8 networks

for (i, network) in enumerate(networks)
    results = run_network_ensemble(network; parameters=parameters)
    results_matrix[:, i] = results
end

# Create DataFrame with metrics as rows and networks as columns
metric_names = ["RMSE", "MAE", "MRE", "MedRE", "Frac RE<0.5", "Avg F_R"];
df = DataFrame(Metric = metric_names)
for (i, network) in enumerate(networks)
    df[!, network] = results_matrix[:, i]
end

println(df)

