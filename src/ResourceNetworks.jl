module ResourceNetworks

    using QuadGK
    using Serialization
    using Graphs
    using ProgressMeter
    using Random, Statistics
    using Distributions
    import Base.show

    export ResourceNetwork, gen_ResourceNetwork, propagate_w!, calculate_E!, count_resources_within_R, propagate_E!

    mutable struct ResourceNetwork
        graph::SimpleGraph
        has_resource::Vector{Bool}
        m::Int64
        l::Int64
        w::Matrix{Int}
        E::Vector{Float64}
        has_marker::Vector{Bool}
        N::Int64
    end

    function gen_ResourceNetwork(G::SimpleGraph, has_resource::Vector{Bool}, m::Int64, l::Int64)
        N = nv(G)  # Number of nodes
        m_l = m ÷ l
        @assert (m_l & (m_l - 1)) == 0 "m/l must be a power of two"

        neg_inf = Int8(0)
        w = fill(neg_inf, m_l, N)
        E = zeros(Float64, N)
        has_marker = fill(true, N)
        dist = Geometric(1/2)

        for i in 1:N
            if has_resource[i]
                j = rand(1:m_l)
                x = rand(dist) + 1

                if x >= 2^l
                    x = 2^l - 1
                    @warn "Capping x at 2^l - 1 for node $i"
                end

                w[j, i] = x
            end
        end

        return ResourceNetwork(G, has_resource, m, l, w, E, has_marker, N)
    end

    function propagate_w!(rn::ResourceNetwork, R::Int)
        G = rn.graph
        for _ in 1:R
            w_new = fill(Int8(0), size(rn.w)...)
            for i in 1:rn.N
                max_vector = rn.w[:, i]
                for nbr in neighbors(G, i)
                    max_vector = max.(max_vector, rn.w[:, nbr])
                end
                w_new[:, i] = max_vector
            end
            rn.w .= w_new
        end
    end

    function calculate_E!(rn::ResourceNetwork)
        m_l = rn.m ÷ rn.l  
        α = alpha(m_l)  # Compute the alpha constant for m/l

        low_threshold = 5/2 * m_l

        Zs = []
        # Iterate over each node to compute E
        for i in 1:rn.N     
            # Compute Z
            Z = 0.0
            for j in 1:m_l
                Z += 2.0^(- rn.w[j, i])
            end     
        if Z == 0.0
                rn.E[i] = 0.0
                @warn "Node $i has Z = 0.0"
                continue
            else 
                Z = 1.0 / Z
            end 

            E =  α * (m_l^2) * Z

            if E ≤ low_threshold
                V = count(rn.w[:,i] .== 0)
                if V != 0
                    E = m_l *log(m_l/V)
                end
            end
                rn.E[i] = E
            end 
        end;

        function propagate_E!(rn::ResourceNetwork; M::Int = rn.N)
            G = rn.graph
            for _ in 1:M
                # Initialize new E and marker states for the next round
                new_E = copy(rn.E)
                new_has_marker = copy(rn.has_marker)
                
                # Iterate over each node in the graph
                for i in 1:rn.N
                    # Check neighbors and compare E values
                    for nbr in neighbors(G, i)
                        if rn.E[nbr] > rn.E[i]
                            new_E[i] = rn.E[nbr]  # Overwrite E value
                            new_has_marker[i] = false  # Set marker to false
                        end
                    end
                end
        
                # Update E and has_marker for the next round
                rn.E .= new_E
                rn.has_marker .= new_has_marker
            end
        end
        
    function show(io::IO, rn::ResourceNetwork)::Nothing
        println(io, "ResourceNetwork")
        return nothing
    end

    function count_resources_within_R(rn::ResourceNetwork, R::Int)::Vector{Int}
        G = rn.graph
        has_resource = rn.has_resource
        N = nv(G)
        resource_counts = zeros(Int, N)

        for start in 1:N
            visited = falses(N)
            visited[start] = true
            frontier = [start]
            count = has_resource[start] ? 1 : 0
            dist = 0

            while dist < R && !isempty(frontier)
                new_frontier = Int[]
                for u in frontier
                    for v in neighbors(G, u)
                        if !visited[v]
                            visited[v] = true
                            if has_resource[v]
                                count += 1
                            end
                            push!(new_frontier, v)
                        end
                    end
                end
                frontier = new_frontier
                dist += 1
            end
            resource_counts[start] = count
        end

        return resource_counts
    end

    ## numeric integration of alpha + caching
    # Path to the cache file
    const ALPHA_CACHE_FILE = "alpha_cache.bin"

    # Load existing cache or create a new empty one
    function load_alpha_cache()
        if isfile(ALPHA_CACHE_FILE)
            return deserialize(ALPHA_CACHE_FILE)
        else
            return Dict{Int,Float64}()
        end
    end

    function save_alpha_cache(cache::Dict{Int,Float64})
        serialize(ALPHA_CACHE_FILE, cache)
    end

    function alpha(gamma::Int)
        @assert gamma > 0 "gamma must be positive"
        # Load or initialize cache
        cache = load_alpha_cache()

        if haskey(cache, gamma)
            return cache[gamma]
        else
            # Compute alpha if not cached
            f(u) = (log2((2+u)) - log2((1+u)))^gamma
            val, err = quadgk(f, 0, Inf; rtol=1e-16, atol=1e-16)
            α = 1 / (gamma * val)

            # Store in cache and save
            cache[gamma] = α
            save_alpha_cache(cache)

            return α
        end
    end
    
end # module