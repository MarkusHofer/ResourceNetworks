module SimulationDatabase

using SQLite, JSON, Serialization, Dates

export run_query,   initialize_database, save_simulations, load_simulation, get_matching_indexes, load_all_matching_simulations

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
                R INTEGER NOT NULL,
                timestamp TEXT NOT NULL,
                git_hash TEXT NOT NULL,
                E BLOB NOT NULL,
                selected_nodes BLOB NOT NULL,
                F_R BLOB NOT NULL,
                optimal_nodes BLOB NOT NULL
            )
        """)
        println("Database initialized successfully: $db_file")
    finally
        SQLite.close(db)
    end
end

# Function to save a simulation
function save_simulations(db_file::String, simulations::Vector{Dict{String, Any}})
    db = SQLite.DB(db_file)
    try
        for sim in simulations
            SQLite.execute(db, """
                INSERT INTO simulations 
                (graph_type, graph_parameters, N, l, m, R, timestamp, git_hash, E, selected_nodes, F_R, optimal_nodes)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, [
                sim["graph_type"],
                JSON.json(sim["graph_parameters"]),
                sim["general_parameters"]["N"],
                sim["general_parameters"]["l"],
                sim["general_parameters"]["m"],
                sim["general_parameters"]["R"],
                sim["metadata"]["timestamp"],
                sim["metadata"]["git_hash"],
                sim["results"]["E"],
                sim["results"]["selected_nodes"],
                sim["results"]["F_R"],
                sim["results"]["optimal_nodes"]
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
                graph_type=row[:graph_type],
                graph_parameters=JSON.parse(row[:graph_parameters]),
                general_parameters=Dict(
                    "N" => row[:N],
                    "l" => row[:l],
                    "m" => row[:m],
                    "R" => row[:R]
                ),
                metadata=Dict(
                    "timestamp" => row[:timestamp],
                    "git_hash" => row[:git_hash]
                ),
                results=Dict(
                    "E" => row[:E],
                    "selected_nodes" => row[:selected_nodes],
                    "F_R" => row[:F_R],
                    "optimal_nodes" => row[:optimal_nodes]
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

end 