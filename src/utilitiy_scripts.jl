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