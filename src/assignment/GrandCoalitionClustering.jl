##########################################################################
# Grand coalition base station clustering.
#
# This means that all BSs cooperate with each other. Note that this might
# mean that the utilities are either zero or -Inf, since the utility model
# is only applicable when IA is feasible.

function GrandCoalitionClustering(channel, network)
    I = get_no_BSs(network); K = get_no_MSs(network)
    aux_params = get_aux_assignment_params(network)

    # Perform cell selection
    LargeScaleFadingCellAssignment!(channel, network)

    a = zeros(Int, I)
    utilities, alphas, _ = longterm_utilities(channel, network, Partition(a))
    Lumberjack.info("GrandCoalitionClustering finished.",
        { :sum_utility => sum(utilities),
          :a => a,
          :alphas => alphas }
    )

    # Store alphas as user priorities for precoding, if desired
    if aux_params["apply_overhead_prelog"]
        set_user_priorities!(network, alphas)
    end

    # Store cluster assignment together with existing cell assignment
    temp_assignment = get_assignment(network)
    network.assignment = Assignment(temp_assignment.cell_assignment, ones(K, I))

    # Return results
    results = AssignmentResults()
    results["utilities"] = utilities
    results["a"] = a
    results["alphas"] = alphas
    results["no_iters"] = 1
    results["no_longterm_rate_calculations"] = K
    results["no_clusters"] = 1 + maximum(a)
    return results
end
