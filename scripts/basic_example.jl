using Graphs
using Random, Statistics
using Distributions
using ProgressMeter
using Plots

include("../src/ResourceNetworkModule.jl"); 
using .ResourceNetworkModule; 

G = Graphs.SimpleGraphs.grid((100, 100), periodic=true); 
has_resource = [rand() < 0.5 for _ in 1:nv(G)];
l = 6;
m = 6*2048;
R = 6; 

RN = gen_ResourceNetwork(G, has_resource, m, l);

propagate_w!(RN, R);
calculate_E!(RN);
propagate_E!(RN)

F_R = count_resources_within_R(RN, R);

@assert argmax(F_R) == findall(RN.has_marker)[1]

using HDF5, SQLite

using SQLite, JSON3

function save_to_hdf5(filename::String, network_type::String, sim_id::String, RN, F_R, max_F_R_node, marker_node, params::Dict)
    h5open(filename, "a") do file
        group_path = "$network_type/$sim_id"
        group = create_group(file, group_path)
        
        # Save parameters
        for (key, value) in params
            write(group, "parameters/$key", value)
        end

        # Save results
        write(group, "results/has_resource", RN.has_resource)
        write(group, "results/F_R", F_R)
        write(group, "results/E", RN.E)
        write(group, "results/has_marker", RN.has_marker)
        write(group, "results/max_F_R_node", max_F_R_node)
        write(group, "results/marker_node", marker_node)
    end
end

function save_to_sqlite(db_filename::String, network_type::String, sim_id::String, hdf5_filename::String, params::Dict, max_F_R_node::Int, marker_node::Int)
    db = SQLite.DB(db_filename)
    params_json = JSON3.write(params)  # Convert parameters to JSON string
    
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS simulations (
            id INTEGER PRIMARY KEY,
            network_type TEXT,
            hdf5_file TEXT,
            group_name TEXT,
            l INTEGER,
            m INTEGER,
            R INTEGER,
            git_branch TEXT,
            git_commit TEXT,
            max_F_R_node INTEGER,
            marker_node INTEGER,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    DBInterface.execute(db, """
        INSERT INTO simulations (network_type, hdf5_file, group_name, parameters, git_branch, git_commit, max_F_R_node, marker_node)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, [
        network_type, hdf5_filename, "$network_type/$sim_id", params_json,
        params["git_branch"], params["git_commit"], max_F_R_node, marker_node
    ])
    
    SQLite.close(db)
end

params = Dict(
    "git_branch" => "main",
    "git_commit" => "abc123",
    "l" => l,
    "m" => m,
    "R" => R
)