"""
    This script checks that the error bounds for the distributed HyperLogLog algorithm are respected.

    The script generates a lattice graph and a resource network on it.
    It then calculates the root mean square error between the counted resources and the expected energy.
    It then checks that the error bounds are respected.
"""

using Pkg
Pkg.activate(".")

using Revise

using Graphs
using Random, Statistics
using Distributions
using ProgressMeter
using Plots
using LaTeXStrings

# Include custom modules for resource networks and metrics
includet("../src/ResourceNetworks.jl"); 
using .ResourceNetworks; 

includet("../src/Metrics.jl"); 
using .Metrics; 

# Create a 100x100 grid graph with periodic boundary conditions
G = Graphs.SimpleGraphs.grid((200, 200), periodic=true); 

# Randomly assign resources to nodes in the graph
has_resource = [rand() < 0.5 for _ in 1:nv(G)];

# Set parameters for the resource network
l = 8;  # register Length 
m = l * 2048;  # message length
R = 15;  # range for resource counting

# Generate the resource network 
RN = gen_ResourceNetwork(G, has_resource, m, l);

# Propagate weights and calculate estimates
propagate_w!(RN, R);
calculate_E!(RN);   

# Count resources within the specified range R (BFS)
F_R = count_resources_within_R(RN, R-1);

# caclulate relative errors
relative_errors = (F_R .- RN.E) ./ F_R ; 

# plot histogram of relative errors manually
bin_edges = range(-0.1, 0.1, length=101)  # 100 bins
bin_centers = (bin_edges[1:end-1] + bin_edges[2:end]) ./ 2
bin_width = bin_edges[2] - bin_edges[1]

# Count points in each bin
counts = zeros(length(bin_centers))
for (i, (left, right)) in enumerate(zip(bin_edges[1:end-1], bin_edges[2:end]))
    counts[i] = sum((relative_errors .>= left) .& (relative_errors .< right))
end

# Normalize counts
counts = counts ./ (nv(G) *bin_width)

# Plot bars
plot(grid=false, frame=:box, legendfont=font(7), fontfamily="Computer Modern", size=(460, 360))

bar!(bin_centers, counts, width=bin_width, label=L"\textrm{Relative\;  Error}\;\; (F_R - E)/F_R", alpha=1.0)

# Plot normal distribution
x = range(-0.1, 0.1, length=1000); 
y = pdf.(Normal(0, 0.023), x)
plot!(x, y, label=L"\textrm{Normal. Dist.} \; \; \mu = 0, \; \; \sigma = 0.023", color=:red, lw=3)
xlims!(-0.055, 0.055)
xlabel!(L"(F_R - E)/F_R")

savefig("figures/error_bounds.pdf")