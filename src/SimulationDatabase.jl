module SimulationDatabase

using SQLite, JSON, Serialization, Dates, Graphs

export run_query, initialize_database, save_simulations, load_simulation, get_matching_indexes, load_all_matching_simulations, prepare_to_save

# Function to initialize the database with the required schema
function initialize_database(db_file::String)
    if isfile(db_file)
        println("Database already exists: $db_file")
        return
    end

    db = SQLite.DB(db_file)
    try
        SQLite.execute(db, """
            CREATE TABLE simulations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                graph_type TEXT NOT NULL,
                graph_parameters TEXT NOT NULL,
                N INTEGER NOT NULL,
                l INTEGER NOT NULL,
                m INTEGER NOT NULL,
                p INTEGER NOT NULL,
                R INTEGER NOT NULL,
                timestamp TEXT NOT NULL,
                git_hash TEXT NOT NULL,
                E BLOB NOT NULL,
                selected_nodes BLOB NOT NULL,
                F_R BLOB NOT NULL,
                optimal_nodes BLOB NOT NULL,
                has_resource BLOB NOT NULL
            )
        """)
        println("Database initialized successfully: $db_file")
    finally
        SQLite.close(db)
    end
end

function prepare_to_save(simulation::Dict, params::Dict; graph_type="null", graph_parameters=Dict())
    # Create a copy of the simulation dictionary
    prepared_simulation = deepcopy(simulation)

    # Add general parameters
    prepared_simulation["general_parameters"] = Dict(
        "N" => nv(params["G"]),
        "l" => params["l"],
        "m" => params["m"],
        "R" => params["R"],
        "p" => params["p"]
    )

    prepared_simulation["graph_type"] = params["graph_type"]
    prepared_simulation["graph_parameters"] = params["graph_parameters"]

    # Add metadata
    prepared_simulation["metadata"] = Dict(
        "git_hash" => get_file_git_hash("src/ResourceNetworks.jl"),
        "timestamp" => Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM")
    )

    # Add results
    prepared_simulation["results"] = Dict(
        "E" => prepared_simulation["E"],
        "F_R" => prepared_simulation["F_R"],
        "selected_nodes" => prepared_simulation["selected_nodes"],
        "optimal_nodes" => argmax(prepared_simulation["F_R"]),
        "has_resource" => prepared_simulation["has_resource"]
    )

    return prepared_simulation
end

# Function to save a simulation
function save_simulations(db_file::String, simulations::Vector{Dict{String, Any}})
    db = SQLite.DB(db_file)
    try
        for sim in simulations
            SQLite.execute(db, """
                INSERT INTO simulations 
                (graph_type, graph_parameters, N, l, m, p, R, timestamp, git_hash, E, selected_nodes, F_R, optimal_nodes, has_resource)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, [
                sim["graph_type"],
                JSON.json(sim["graph_parameters"]),
                sim["general_parameters"]["N"],
                sim["general_parameters"]["l"],
                sim["general_parameters"]["m"],
                sim["general_parameters"]["p"],
                sim["general_parameters"]["R"],
                sim["metadata"]["timestamp"],
                sim["metadata"]["git_hash"],
                sim["results"]["E"],
                sim["results"]["selected_nodes"],
                sim["results"]["F_R"],
                sim["results"]["optimal_nodes"],
                sim["results"]["has_resource"]
            ])
        end
    finally
        SQLite.close(db)
    end
end

# Function to load a simulation by ID
function load_simulations(db_file::String, ids::Vector{Int})
    db = SQLite.DB(db_file)
    simulations = []
    try
        for id in ids
            results = DBInterface.execute(db, """
                SELECT * FROM simulations WHERE id = ?
            """, (id,))
            row = first(results)
            push!(simulations, (
                Dict(
                    "N" => row[:N],
                    "l" => row[:l],
                    "m" => row[:m],
                    "R" => row[:R],
                    "timestamp" => row[:timestamp],
                    "git_hash" => row[:git_hash],
                    "E" => row[:E],
                    "selected_nodes" => row[:selected_nodes],
                    "F_R" => row[:F_R],
                    "optimal_nodes" => row[:optimal_nodes],
                    "graph_type" => row[:graph_type],
                    "graph_parameters" => JSON.parse(row[:graph_parameters])
                )
            ))
        end
    finally
        SQLite.close(db)
    end
    return simulations
end

# Function to retrieve matching IDs based on a query
function get_matching_indexes(db_file::String, query::String, params=())
    db = SQLite.DB(db_file)
    try
        results = DBInterface.execute(db, query, params)
        return [row[:id] for row in results]
    finally
        SQLite.close(db)
    end
end

function run_query(db_file::String, query::String, params=())
    # Get all matching IDs
    matching_indexes = get_matching_indexes(db_file, query, params)

    # Load all simulations for the matching IDs
    return load_simulations(db_file, matching_indexes)
end

function get_file_git_hash(file_path::String)
    # Ensure the file path is relative to the Git repository root
    cmd = `git log -n 1 --pretty=format:%H -- $file_path`
    try
        hash = read(cmd, String)
        return strip(hash)  # Remove any trailing newline or spaces
    catch e
        error("Failed to get Git hash for $file_path: $e")
    end
end

end 