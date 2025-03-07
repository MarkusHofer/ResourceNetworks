"""
    This script shows the basic usage of the ResourceNetworks.jl

    The script generates a resource network and calculates the root mean square error 
    between the counted resources and the estimates based on the disbtributed HyperLogLog algorithm.
"""

using Pkg
Pkg.activate(".")

using Revise

using Graphs
using Random, Statistics
using Distributions
using ProgressMeter
using Plots

# Include custom modules for resource networks and metrics
includet("../src/ResourceNetworks.jl"); 
using .ResourceNetworks; 

includet("../src/Metrics.jl"); 
using .Metrics; 

# Create a 100x100 grid graph with periodic boundary conditions
G = Graphs.SimpleGraphs.grid((100, 100), periodic=true); 

# Randomly assign resources to nodes in the graph
has_resource = [rand() < 0.5 for _ in 1:nv(G)];

# Set parameters for the resource network
l = 5;  # Message Length 
m = l * 128;  # bits per message 
R = 4;  # Range for resource counting

# Generate the resource network 
RN = gen_ResourceNetwork(G, has_resource, m, l);

# Propagate weights and calculate estimates
propagate_w!(RN, R);
calculate_E!(RN);   

# Count resources within the specified range R (BFS)
F_R = count_resources_within_R(RN, R);

# Calculate the root mean square error between counted resources and expected energy
rmse(F_R, RN.E)

