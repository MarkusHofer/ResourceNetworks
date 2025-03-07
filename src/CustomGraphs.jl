module CustomGraphs

using Graphs, Random, ProgressMeter, Statistics

export popularity_similarity_network, random_configuration_model, minmax_networks, average_clustering, 
       save_adjacency_list_txt, load_adjacency_list_txt

"""
    random_configuration_model(total_nodes::Int, k::Int)

Generate a network using the random configuration model.

# Arguments
- `total_nodes::Int`: Number of nodes in the network.
- `k::Int`: Degree for each node.
"""

function random_configuration_model(total_nodes::Int, k::Int)
    if isodd(total_nodes * k)
        error("Invalid configuration: total degree must be even.")
    end
    if k ≥ total_nodes
        error("Invalid configuration: k must be less than total number of nodes.")
    end

    while true
        stubs = vcat([fill(i, k) for i in 1:total_nodes]...)
        shuffle!(stubs)

        valid = true
        edges = Set{Tuple{Int,Int}}()

        for i in 1:2:length(stubs)
            u = stubs[i]
            v = stubs[i+1]
            if u == v || (min(u,v), max(u,v)) in edges
                valid = false
                break
            end
            push!(edges, (min(u,v), max(u,v)))
        end

        if valid
            g = SimpleGraph(total_nodes)
            for (u, v) in edges
                add_edge!(g, u, v)
            end
            return g
        end
    end
end

"""
    propose_move(g::SimpleGraph)

Propose a new graph by rewiring a randomly selected pair of edges.

Two distinct edges (u,v) and (x,y) are selected. One of the two possible rewirings—
either (u,x) & (v,y) or (u,y) & (v,x)—is attempted. Moves that would create self-loops
or duplicate edges are rejected.
"""
function propose_move(g::SimpleGraph)
    candidate = deepcopy(g)
    es = collect(edges(candidate))
    max_trials = 100
    for _ in 1:max_trials
        if length(es) < 2
            return candidate
        end
        e1, e2 = rand(es, 2)
        u, v = src(e1), dst(e1)
        x, y = src(e2), dst(e2)
        # Ensure the four vertices are distinct for a swap
        if length(Set([u, v, x, y])) < 4
            continue
        end
        # Option 1: (u,x) and (v,y)
        if !has_edge(candidate, u, x) && !has_edge(candidate, v, y) && u != x && v != y
            rem_edge!(candidate, u, v)
            rem_edge!(candidate, x, y)
            add_edge!(candidate, u, x)
            add_edge!(candidate, v, y)
            return candidate
        end
        # Option 2: (u,y) and (v,x)
        if !has_edge(candidate, u, y) && !has_edge(candidate, v, x) && u != y && v != x
            rem_edge!(candidate, u, v)
            rem_edge!(candidate, x, y)
            add_edge!(candidate, u, y)
            add_edge!(candidate, v, x)
            return candidate
        end
    end
    # Return candidate unmodified if no valid move is found.
    return candidate
end

"""
    minmax_networks(total_nodes::Int, k::Int; 
    property_func::Function = global_clustering_coefficient, 
    optimize::Symbol = :max, 
    max_iter::Int = 10_000, 
    initial_temp::Float64 = 1.0, 
    cooling_rate::Float64 = 0.99)

Generate a network using the random configuration model and then perform simulated annealing
to optimize a network property. The property to be optimized is provided by `property_func`.

# Arguments
- `total_nodes::Int`: Number of nodes in the network.
- `k::Int`: Degree for each node.
- `property_func::Function`: Function that accepts a graph and returns a scalar property.
  Defaults to `average_clustering`.
- `optimize::Symbol`: `:max` to maximize or `:min` to minimize the property (default: `:max`).
- `max_iter::Int`: Maximum number of iterations for simulated annealing (default: 10,000).
- `initial_temp::Float64`: Starting temperature (default: 1.0).
- `cooling_rate::Float64`: Cooling rate per iteration (default: 0.99).

# Returns
- `best_network::SimpleGraph`: The network with the optimal property found.
- `best_property::Float64`: The corresponding property value.
"""
function minmax_networks(total_nodes::Int, k::Int; 
    property_func::Function = global_clustering_coefficient, 
    optimize::Symbol = :max, 
    max_iter::Int = 10_000, 
    initial_temp::Float64 = 1.0, 
    cooling_rate::Float64 = 0.99)

    current_network = random_configuration_model(total_nodes, k)
    current_property = property_func(current_network)

    best_network = deepcopy(current_network)
    best_property = current_property

    temp = initial_temp

    for iter in 1:max_iter
        candidate_network = propose_move(current_network)
        # Reject candidate moves that result in a disconnected network.
        if !is_connected(candidate_network)
            continue
        end

        candidate_property = property_func(candidate_network)

        # Compute the effective delta based on optimization goal.
        Δ = optimize == :max ? (candidate_property - current_property) : (current_property - candidate_property)

        if Δ >= 0 || rand() < exp(Δ / temp)
        current_network = candidate_network
        current_property = candidate_property

            if (optimize == :max && current_property > best_property) ||
                (optimize == :min && current_property < best_property)
                best_network = deepcopy(current_network)
                best_property = current_property
            end
        
        end
        
        temp *= cooling_rate
        
        end

    return best_network, best_property
end

"""
    save_adjacency_list_txt(adj_list::Vector{Vector{Int}}, title::String, filename::String)

Save an adjacency list and its title to a plain text file.
The format is:
# Title: [title]
# Number of nodes: [N]
# Each line contains space-separated neighbor indices for that node

# Arguments
- `adj_list`: Vector of vectors containing neighbor indices for each node
- `title`: String describing the graph
- `filename`: Name of the file to save to (without extension)
```
"""
function save_adjacency_list_txt(adj_list::Vector{Vector{Int}}, title::String, filename::String)
    N = length(adj_list)
    
    open("$(filename).txt", "w") do f
        println(f, "# Title: $title")
        println(f, "# Number of nodes: $N")
        println(f, "# Each line contains space-separated neighbor indices for that node")
        println(f)  # Empty line for readability
        
        for neighbors in adj_list
            println(f, join(neighbors, " "))
        end
    end
end

"""
    load_adjacency_list_txt(filename::String)

Load an adjacency list and its metadata from a plain text file.

# Arguments
- `filename`: Name of the file to load (without extension)

# Returns
- `adj_list`: Vector of vectors containing neighbor indices
- `title`: String describing the graph
- `N`: Number of nodes in the graph
```
"""
function load_adjacency_list_txt(filename::String)
    adj_list = Vector{Vector{Int}}()
    title = ""
    N = 0
    
    open("$(filename).txt", "r") do f
        # Read header
        title_line = readline(f)
        title = split(title_line, ": ")[2]
        
        N_line = readline(f)
        N = parse(Int, split(N_line, ": ")[2])
        
        # Skip comment line and empty line
        readline(f)
        readline(f)
        
        # Read adjacency lists
        for _ in 1:N
            line = readline(f)
            neighbors = parse.(Int, split(line))
            push!(adj_list, neighbors)
        end
    end
    
    return adj_list, title, N
end

"""
    adjacency_list_to_graph(adj_list::Vector{Vector{Int}})

Convert a 0-based adjacency list to a Graphs.jl SimpleGraph (1-based).

# Arguments
- `adj_list`: Vector of vectors containing neighbor indices (0-based)

# Returns
- `SimpleGraph`: A Graphs.jl graph object with 1-based indexing

# Example
```julia
adj_list, title, N = load_adjacency_list_txt("matrix_A")
G = adjacency_list_to_graph(adj_list)
```
"""
function adjacency_list_to_graph(adj_list::Vector{Vector{Int}})
    N = length(adj_list)
    G = SimpleGraph(N)
    
    # Convert from 0-based to 1-based indexing
    for i in 1:N
        for j in adj_list[i]
            # Add 1 to both i and j to convert to 1-based indexing
            # Only add edge if i < j+1 to avoid adding edges twice
            if i-1 < j  # Compare in 0-based to match file format
                add_edge!(G, i, j+1)
            end
        end
    end
    
    return G
end

end # module
