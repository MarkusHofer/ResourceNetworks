module CustomGraphs

using Graphs
using Random
using ProgressMeter  # Optional: for progress visualization in large graphs

export popularity_similarity_network

"""
Generate a network based on the popularity-similarity model for large graphs.

# Arguments
- `total_nodes::Int`: The total number of nodes in the network.
- `m::Int`: The number of edges each new node creates.

# Returns
- `g::SimpleGraph`: The generated graph.
- `positions::Dict{Int, Tuple{Float64, Float64}}`: Node positions in polar coordinates (r, θ).
"""
function popularity_similarity_network(total_nodes::Int, m::Int)
    # Initialize the graph
    g = SimpleGraph(total_nodes)
    
    # Store positions in polar coordinates (r, θ)
    positions = Dict{Int, Tuple{Float64, Float64}}()

    for i in 1:total_nodes
        # Assign coordinates to the new node
        r = log(i)
        θ = 2π * rand()
        positions[i] = (r, θ)
    end

    # Precompute distances
    distances = Matrix{Float64}(undef, total_nodes, total_nodes)

    for i in 2:total_nodes
        for j in 1:i-1
            distances[i, j] = hyperbolic_distance(positions[i], positions[j])
        end
    end

    # Add edges to the graph
    @showprogress "Adding edges..." for i in 2:total_nodes
        # Get the `m` closest nodes for the current node
        neighbor_candidates = [(distances[i, j], j) for j in 1:i-1]
        closest_neighbors = sort(neighbor_candidates, by = x -> x[1])[1:min(m, i-1)]
        
        # Add edges to the graph
        for (_, neighbor) in closest_neighbors
            add_edge!(g, i, neighbor)
        end
    end

    return g
end

"""
Compute the hyperbolic distance between two nodes in polar coordinates.
"""
function hyperbolic_distance(pos1::Tuple{Float64, Float64}, pos2::Tuple{Float64, Float64})
    r1, θ1 = pos1
    r2, θ2 = pos2
    angular_diff = min(abs(θ2 - θ1), 2π - abs(θ2 - θ1))  
    return r1 + r2 + log(angular_diff^2 / 2)
end

end  # module CustomGraphs