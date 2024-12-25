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
