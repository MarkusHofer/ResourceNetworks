using Distributed
addprocs(8); 

@everywhere using Graphs, Random, Statistics, Distributions
@everywhere using ProgressMeter, UnPack
@everywhere include("../src/ResourceNetworks.jl")
@everywhere using .ResourceNetworks

# Include the SimulationDatabase module
include("../src/SimulationDatabase.jl")
using .SimulationDatabase

# Function to perform a single resource experiment
@everywhere function resource_experiment(parameters::Dict)
    @unpack G, l, m, R, p = parameters

    # Initialize the resource network
    has_resource = [rand() < p for _ in 1:nv(G)]
    RN = gen_ResourceNetwork(G, has_resource, m, l)

    # Simulate the resource propagation
    propagate_w!(RN, R)
    calculate_E!(RN)
    E = copy(RN.E)
    propagate_E!(RN)
    F_R = count_resources_within_R(RN, R)
    selected = findall(RN.has_marker)

    # Return results as a dictionary
    return Dict{String, Any}(
        "E" => E,
        "F_R" => F_R,
        "selected_nodes" => selected,
        "has_resource" => has_resource
    )
end

params = Dict(
    "G" => Graphs.SimpleGraphs.grid((100,100), periodic=true),
    "l" => 6, 
    "m" => 6*1024,
    "R" => 12, 
    "p" => 0.05,
    "graph_type" => "grid", 
    "graph_parameters" => Dict("periodic" => true)
); 

param_list = [params for i in 1:8];

results = @showprogress pmap(resource_experiment, param_list); 

prepared_results = [
    prepare_to_save(sim, param_list[i])
    for (i, sim) in enumerate(results)
];

initialize_database("simulations.db") # Create the database if it doesn't exist
save_simulations("simulations.db", prepared_results)

println("Done!")


using ProgressMeter
ps = collect(0.05:0.05:0.9)
Rs = collect(4:2:16)

@showprogress for (p,R) in Iterators.product(ps, Rs)

    params = Dict(
    "G" => Graphs.SimpleGraphs.grid((100,100), periodic=true),
    "l" => 6, 
    "m" => 6*1024,
    "R" => R, 
    "p" => p,
    "graph_type" => "grid", 
    "graph_parameters" => Dict("periodic" => true)
    ); 

    param_list = [params for i in 1:32];

    results = pmap(resource_experiment, param_list); 

    prepared_results = [
        prepare_to_save(sim, param_list[i])
        for (i, sim) in enumerate(results)
    ];

    save_simulations("simulations.db", prepared_results)

end

