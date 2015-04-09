#!/usr/bin/env julia

require("../../../../../src/IAClustering.jl")
using IAClustering, CoordinatedPrecoding
require("../../plot_params.jl")

##########################################################################
# General settings
seed = 2836363
start_time = strftime("%Y%m%dT%H%M%S", time())

##########################################################################
# Initial simulation params
initial_simulation_params = [
    "simulation_name" => "initial",
    "I" => 15, "Kc" => 1, "N" => 2, "M" => 2, "d" => 1,
    "Ndrops" => 100, "Nsim" => 10,
    "geography_length" => 250.,
    "MS_serving_BS_distance" => 50.,
    "assignment_methods" => [
        # ExhaustiveSearchClustering,
        # BranchAndBoundClustering,

        CoalitionFormationClustering_Group,
        CoalitionFormationClustering_Individual,

        # Chen2014_ExhaustiveSearch,
        # Peters2012_Heuristic,

        GrandCoalitionClustering,
        GreedyClustering,
        RandomClustering,
        NoClustering,
    ],
    "precoding_methods" => [
        RobustIntraclusterLeakageMinimization,
    ],
    "aux_network_params" => [
        "no_coherence_symbols" => 1000,
    ],
    "aux_assignment_params" => [
        "clustering_type" => :spectrum_sharing,
        "apply_overhead_prelog" => true,
        "IA_infeasible_negative_inf_utility" => true,
        "replace_E1_utility_with_lower_bound" => false,

        "CoalitionFormationClustering_Group:max_merge_size" => 3,
        "CoalitionFormationClustering_Group:search_order" => :greedy,
        "CoalitionFormationClustering_Individual:search_budget" => 50,
        "CoalitionFormationClustering_Individual:search_order" => :greedy,
        "CoalitionFormationClustering_Individual:stability_type" => :nash,
    ],
    "aux_precoding_params" => [
        "initial_precoders" => "eigendirection",
        "stop_crit" => 1e-3,
        "max_iters" => 1000,
    ],
    "independent_variable" => (set_transmit_powers_dBm!, -50:10:0),
]

##########################################################################
# Generate network
network =
    setup_random_large_scale_network(initial_simulation_params["I"],
        initial_simulation_params["Kc"], initial_simulation_params["N"], initial_simulation_params["M"],
        no_streams=initial_simulation_params["d"],
        geography_width=initial_simulation_params["geography_length"],
        geography_height=initial_simulation_params["geography_length"],
        MS_serving_BS_distance=initial_simulation_params["MS_serving_BS_distance"])

##########################################################################
# Compare different settings for group-based coalition formation
simulation_params = deepcopy(initial_simulation_params)

simulation_params["simulation_name"] = "group-greedy"
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Group:search_order"] = :greedy

srand(seed)
raw_precoding_results, raw_assignment_results =
    simulate(network, simulation_params, loop_over=:assignment_methods)

processed_results = postprocess(raw_precoding_results, simulation_params, plot_params_instantaneous_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_sumrate)
plot(processed_results, simulation_params, plot_params_longterm_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_iters)
plot(processed_results, simulation_params, plot_params_longterm_iters)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_clusters)
plot(processed_results, simulation_params, plot_params_longterm_clusters)

simulation_params["simulation_name"] = "group-lexicographic"
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Group:search_order"] = :lexicographic

srand(seed)
raw_precoding_results, raw_assignment_results =
    simulate(network, simulation_params, loop_over=:assignment_methods)

processed_results = postprocess(raw_precoding_results, simulation_params, plot_params_instantaneous_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_sumrate)
plot(processed_results, simulation_params, plot_params_longterm_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_iters)
plot(processed_results, simulation_params, plot_params_longterm_iters)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_clusters)
plot(processed_results, simulation_params, plot_params_longterm_clusters)

##########################################################################
# Compare different settings for group-based coalition formation
simulation_params = deepcopy(initial_simulation_params)

simulation_params["simulation_name"] = "individual-greedy,nash"
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:search_order"] = :greedy
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:stability_type"] = :nash

srand(seed)
raw_precoding_results, raw_assignment_results =
    simulate(network, simulation_params, loop_over=:assignment_methods)

processed_results = postprocess(raw_precoding_results, simulation_params, plot_params_instantaneous_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_sumrate)
plot(processed_results, simulation_params, plot_params_longterm_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_iters)
plot(processed_results, simulation_params, plot_params_longterm_iters)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_clusters)
plot(processed_results, simulation_params, plot_params_longterm_clusters)

simulation_params["simulation_name"] = "individual-greedy,individual"
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:search_order"] = :greedy
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:stability_type"] = :individual

srand(seed)
raw_precoding_results, raw_assignment_results =
    simulate(network, simulation_params, loop_over=:assignment_methods)

processed_results = postprocess(raw_precoding_results, simulation_params, plot_params_instantaneous_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_sumrate)
plot(processed_results, simulation_params, plot_params_longterm_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_iters)
plot(processed_results, simulation_params, plot_params_longterm_iters)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_clusters)
plot(processed_results, simulation_params, plot_params_longterm_clusters)

simulation_params["simulation_name"] = "individual-greedy,contractual"
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:search_order"] = :greedy
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:stability_type"] = :contractual

srand(seed)
raw_precoding_results, raw_assignment_results =
    simulate(network, simulation_params, loop_over=:assignment_methods)

processed_results = postprocess(raw_precoding_results, simulation_params, plot_params_instantaneous_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_sumrate)
plot(processed_results, simulation_params, plot_params_longterm_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_iters)
plot(processed_results, simulation_params, plot_params_longterm_iters)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_clusters)
plot(processed_results, simulation_params, plot_params_longterm_clusters)

simulation_params["simulation_name"] = "individual-fair,nash"
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:search_order"] = :fair
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:stability_type"] = :nash

srand(seed)
raw_precoding_results, raw_assignment_results =
    simulate(network, simulation_params, loop_over=:assignment_methods)

processed_results = postprocess(raw_precoding_results, simulation_params, plot_params_instantaneous_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_sumrate)
plot(processed_results, simulation_params, plot_params_longterm_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_iters)
plot(processed_results, simulation_params, plot_params_longterm_iters)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_clusters)
plot(processed_results, simulation_params, plot_params_longterm_clusters)

simulation_params["simulation_name"] = "individual-fair,individual"
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:search_order"] = :fair
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:stability_type"] = :individual

srand(seed)
raw_precoding_results, raw_assignment_results =
    simulate(network, simulation_params, loop_over=:assignment_methods)

processed_results = postprocess(raw_precoding_results, simulation_params, plot_params_instantaneous_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_sumrate)
plot(processed_results, simulation_params, plot_params_longterm_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_iters)
plot(processed_results, simulation_params, plot_params_longterm_iters)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_clusters)
plot(processed_results, simulation_params, plot_params_longterm_clusters)

simulation_params["simulation_name"] = "individual-fair,contractual"
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:search_order"] = :fair
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:stability_type"] = :contractual

srand(seed)
raw_precoding_results, raw_assignment_results =
    simulate(network, simulation_params, loop_over=:assignment_methods)

processed_results = postprocess(raw_precoding_results, simulation_params, plot_params_instantaneous_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_sumrate)
plot(processed_results, simulation_params, plot_params_longterm_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_iters)
plot(processed_results, simulation_params, plot_params_longterm_iters)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_clusters)
plot(processed_results, simulation_params, plot_params_longterm_clusters)

simulation_params["simulation_name"] = "individual-random,nash"
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:search_order"] = :random
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:stability_type"] = :nash

srand(seed)
raw_precoding_results, raw_assignment_results =
    simulate(network, simulation_params, loop_over=:assignment_methods)

processed_results = postprocess(raw_precoding_results, simulation_params, plot_params_instantaneous_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_sumrate)
plot(processed_results, simulation_params, plot_params_longterm_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_iters)
plot(processed_results, simulation_params, plot_params_longterm_iters)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_clusters)
plot(processed_results, simulation_params, plot_params_longterm_clusters)

simulation_params["simulation_name"] = "individual-random,individual"
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:search_order"] = :random
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:stability_type"] = :individual

srand(seed)
raw_precoding_results, raw_assignment_results =
    simulate(network, simulation_params, loop_over=:assignment_methods)

processed_results = postprocess(raw_precoding_results, simulation_params, plot_params_instantaneous_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_sumrate)
plot(processed_results, simulation_params, plot_params_longterm_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_iters)
plot(processed_results, simulation_params, plot_params_longterm_iters)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_clusters)
plot(processed_results, simulation_params, plot_params_longterm_clusters)

simulation_params["simulation_name"] = "individual-random,contractual"
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:search_order"] = :random
simulation_params["aux_assignment_params"]["CoalitionFormationClustering_Individual:stability_type"] = :contractual

srand(seed)
raw_precoding_results, raw_assignment_results =
    simulate(network, simulation_params, loop_over=:assignment_methods)

processed_results = postprocess(raw_precoding_results, simulation_params, plot_params_instantaneous_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_sumrate)
plot(processed_results, simulation_params, plot_params_longterm_sumrate)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_iters)
plot(processed_results, simulation_params, plot_params_longterm_iters)
processed_results = postprocess(raw_assignment_results, simulation_params, plot_params_longterm_clusters)
plot(processed_results, simulation_params, plot_params_longterm_clusters)