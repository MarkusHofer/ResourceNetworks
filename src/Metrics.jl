module Metrics

using Statistics

export rmse, mae, mre, medre, frac_re_lt

"""
    rmse(x, y)

Calculate Root Mean Square Error between vectors x and y.
"""
function rmse(x, y)
    n = length(x)
    cum_square_error = sum((x .- y).^2)
    return sqrt(cum_square_error / n)
end

"""
    mae(x, y)

Calculate Mean Absolute Error between vectors x and y.
"""
function mae(x, y)
    n = length(x)
    cum_abs_error = sum(abs.(x .- y))
    return cum_abs_error / n
end

"""
    mre(x, y)

Calculate Mean Relative Error between vectors x and y.
Only includes non-zero denominators and cases where both values are zero.
"""
function mre(x, y)
    # Only include non-zero denominators and cases where both are zero
    valid_indices = findall(i -> y[i] != 0 || (y[i] == 0 && x[i] == 0), 1:length(y))
    if isempty(valid_indices)
        return 0.0
    end
    
    rel_errors = abs.(x[valid_indices] .- y[valid_indices]) ./ max.(y[valid_indices], eps())
    return mean(rel_errors)
end

"""
    medre(x, y)

Calculate Median Relative Error between vectors x and y.
Similar to MRE but uses median instead of mean for better robustness to outliers.
"""
function medre(x, y)
    # Only include non-zero denominators and cases where both are zero
    valid_indices = findall(i -> y[i] != 0 || (y[i] == 0 && x[i] == 0), 1:length(y))
    if isempty(valid_indices)
        return 0.0
    end
    
    rel_errors = abs.(x[valid_indices] .- y[valid_indices]) ./ max.(y[valid_indices], eps())
    return median(rel_errors)
end

"""
    frac_re_lt(x, y, threshold=0.5)

Calculate the fraction of nodes with relative error less than the given threshold.
Handles special cases:
- If y[i] = 0 and x[i] = 0: counts as RE = 0 (included in fraction)
- If y[i] = 0 and x[i] ≠ 0: counts as RE = Inf (not included in fraction)
"""
function frac_re_lt(x, y, threshold=0.5)
    n = length(x)
    count = 0
    
    for i in 1:n
        if y[i] != 0
            re = abs(x[i] - y[i]) / y[i]
            if re < threshold
                count += 1
            end
        elseif x[i] == 0  # Both zero case
            count += 1
        end
        # y[i] = 0 and x[i] ≠ 0 case is not counted
    end
    
    return count / n
end

end # module 