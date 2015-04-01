# Base station clustering based on coalitional formation.

type CoalitionFormationClustering_IndividualState
    partition::Partition
    BS_utilities::Vector{Float64}
    no_searches::Vector{Int}
end

function CoalitionFormationClustering_Individual(channel, network)
    I = get_no_BSs(network)

    aux_params = get_aux_assignment_params(network)
    @defaultize_param! aux_params "CoalitionFormationClustering:search_budget" 50
    search_budget = aux_params["CoalitionFormationClustering:search_budget"]

    # Perform cell selection
    LargeScaleFadingCellAssignment!(channel, network)
    temp_cell_assignment = get_assignment(network)

    # Initial coalition structure is the non-cooperative state
    initial_partition = Partition(collect(0:(I-1)))
    initial_BS_utilities = longterm_BS_utilities(channel, network, initial_partition, temp_cell_assignment, I)
    initial_no_searches = zeros(Int, I)
    state = CoalitionFormationClustering_IndividualState(initial_partition, initial_BS_utilities, initial_no_searches)

    # Perform coalitional formation until no BS deviates
    deviation_performed = true
    while deviation_performed
        deviation_performed = false

        # Give all BSs a chance to deviate
        for i = 1:I
            if deviate!(i, I, state, search_budget, channel, network, temp_cell_assignment)
                deviation_performed = true
            end
        end

    end
    utilities, _ = longterm_utilities(channel, network, state.partition)
    Lumberjack.info("CoalitionFormationClustering finished.", { :sum_utility => sum(utilities), :a => restricted_growth_string(state.partition), :no_searches => state.no_searches })

    # Store cluster assignment together with existing cell assignment
    temp_assignment = get_assignment(network)
    network.assignment = Assignment(temp_assignment.cell_assignment, cluster_assignment_matrix(network, state.partition))

    # Return results
    results = AssignmentResults()
    results["utilities"] = utilities
    return results
end

# Lets BS i deviate. Returns true if it did deviate, otherwise false.
function deviate!(i, I, state, search_budget, channel, network, cell_assignment)
    # First check that we have not exceeded our search budget
    if state.no_searches[i] >= search_budget
        return false
    end

    # Divide blocks such that old_block is the block that BS i used to
    # belong to, and other_blocks is an array of all other blocks.
    old_block = Block() # to store variable from inside loop
    other_blocks = Block[]
    for block in state.partition.blocks
        if i in block.elements
            old_block = Block(setdiff(block.elements, IntSet(i))) # BS i does not belong to the old_block anymore
        else
            push!(other_blocks, block)
        end
    end

    # Create all possible deviations for BS i
    BS_not_singleton_coalition_before = length(old_block) > 0 ? true : false # was this BS not in a singleton coalition before?
    no_new_partitions = length(other_blocks) + int(BS_not_singleton_coalition_before)
    new_partitions = Array(Partition, no_new_partitions)
    deviating_BS_utilities = zeros(Float64, I, no_new_partitions)
    for n = 1:length(other_blocks)
        # Loop over the deviations where BS i joins an existing coalition
        new_partition = Partition()
        other_blocks_cp = deepcopy(other_blocks) # need to deepcopy, so the created coalitions will not all be the same...
        union!(new_partition.blocks, other_blocks_cp)

        # Add the old block unless it used to be a singleton
        if BS_not_singleton_coalition_before
            push!(new_partition.blocks, old_block)
        end

        # Add BS i to coalition n
        push!(other_blocks_cp[n].elements, i)

        new_partitions[n] = new_partition
        deviating_BS_utilities[:,n] = longterm_BS_utilities(channel, network, new_partition, cell_assignment, I)
    end
    if BS_not_singleton_coalition_before
        # BS i was in a non-singleton coalition before deviation. Add the the
        # possibility that it belongs to a non-singleton coalition after deviation.
        new_partition = Partition()
        other_blocks_cp = deepcopy(other_blocks)
        union!(new_partition.blocks, other_blocks_cp)

        # Add the old block
        push!(new_partition.blocks, old_block)

        # Add BS i to new singleton coalition
        push!(new_partition.blocks, Block(IntSet(i)))

        new_partitions[end] = new_partition
        deviating_BS_utilities[:,end] = longterm_BS_utilities(channel, network, new_partition, cell_assignment, I)
    end

    # Check deviations, trying to join the coalitions in the order that
    # benefits BS i the most.
    for sort_idx in sortperm(squeeze(deviating_BS_utilities[i,:], 1), rev=true)
        # Stop searching if we hit a deviation that results in worse performance.
        # (This is OK since we are looping over a sorted array.)
        if deviating_BS_utilities[i,sort_idx] < state.BS_utilities[i]
            return false
        end

        # Stop searching if we otherwise would exceed our search budget.
        if state.no_searches[i] >= search_budget
            return false
        end

        # Let's see if the other BSs allow BS i to join them
        state.no_searches[i] += 1

        # Find block that BS i belongs to in this partition
        my_block = Block()
        for block in new_partitions[sort_idx].blocks
            if i in block.elements
                my_block = block
                break
            end
        end

        Lumberjack.debug("Coal: Trying to add BS $i to $(my_block)")

        # Check if the existing members of this coalition allow BS i to join (this check includes BS i, unnecessarily)
        BSs_in_block = collect(my_block.elements)
        if all(deviating_BS_utilities[BSs_in_block,sort_idx] .> state.BS_utilities[BSs_in_block])
            # Let BS i join this coalition
            state.partition = new_partitions[sort_idx]
            state.BS_utilities = deviating_BS_utilities[:,sort_idx]

            Lumberjack.debug("Coal: Successful")

            return true
        end
    end
    Lumberjack.debug("BS $i did not deviate.")
    return false
end

# Calculates the sum utility of the served MSs for each BS. assignment and I
# are sent as part of the function signature to speed up evaluation slightly.
function longterm_BS_utilities(channel, network, partition, cell_assignment, I)
    BS_utilities = zeros(Float64, I)
    utilities, _ = longterm_utilities(channel, network, partition)
    for j = 1:I; for l in served_MS_ids(j, cell_assignment)
        BS_utilities[j] += utilities[l]
    end; end
    return BS_utilities
end
