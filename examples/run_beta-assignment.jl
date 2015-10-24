#!/usr/bin/env julia

##########################################################################
# run_beta-assignment.jl
#
# Performance as a function of network SDMA beta, comparing different
# cluster assignment methods.
##########################################################################

using CoordinatedPrecoding, DistributedBaseStationClustering
using Compat, JLD

##########################################################################
# General settings
srand(725242)
start_time = @compat Libc.strftime("%Y%m%dT%H%M%S", time())

##########################################################################
# RandomLargeScaleNetwork
simulation_params = @compat Dict(
    "simulation_name" => "beta-assignment_$(start_time)",
    "I" => 12, "Kc" => 2, "N" => 2, "M" => 8, "d" => 1,
    "Ndrops" => 10, "Nsim" => 5,
    "geography_size" => (1500.,1500.),
    "MS_serving_BS_distance" => Nullable(150.),
    "assignment_methods" => [
        # ExhaustiveSearchClustering,
        BranchAndBoundClustering,

        CoalitionFormationClustering_AttachOrSupplant,
        CoalitionFormationClustering_Attach,

        GreedyClustering_Single,
        GreedyClustering_Multiple,

        # Chen2014_LinearObj_ExhaustiveSearch,
        Chen2014_kmeans,
        Peters2012_Heuristic,

        GrandCoalitionClustering,
        RandomClustering,
        NoClustering,
    ],
    "precoding_methods" => [ RobustIntraclusterWMMSE, ],
    "aux_network_params" => Dict(
        "num_coherence_symbols" => 2500,
        "beta_network_sdma" => 0.8,
    ),
    "aux_assignment_params" => Dict(
        "BranchAndBoundClustering:branching_rule" => :dfs,
        "BranchAndBoundClustering:max_abs_optimality_gap" => 0.,
        "BranchAndBoundClustering:max_rel_optimality_gap" => 0.,
        "BranchAndBoundClustering:E1_bound_in_rate_bound" => false,
        "BranchAndBoundClustering:store_evolution" => false,

        "CoalitionFormationClustering:search_order" => :random,
        "CoalitionFormationClustering:stability_type" => :individual,
        "CoalitionFormationClustering:search_budget" => 100,
        "CoalitionFormationClustering:use_history" => true,
        "CoalitionFormationClustering:starting_point" => :singletons,
    ),
    "aux_precoding_params" => Dict(
        "initial_precoders" => "eigendirection",
        "stop_crit" => 1e-2,
        "max_iters" => 1000,
    ),
    "independent_variable" => ((n, v) -> set_aux_network_param!(n, v, "beta_network_sdma"), 0:0.05:1),
    "aux_independent_variables" => [ (set_average_SNRs_dB!, [30]), ]
)
network =
    setup_random_large_scale_network(simulation_params["I"],
        simulation_params["Kc"], simulation_params["N"], simulation_params["M"],
        num_streams=simulation_params["d"],
        geography_size=simulation_params["geography_size"],
        MS_serving_BS_distance=simulation_params["MS_serving_BS_distance"])

raw_precoding_results, raw_assignment_results =
    simulate(network, simulation_params, loop_over=:assignment_methods)

println("-- Saving $(simulation_params["simulation_name"]) results")
save("$(simulation_params["simulation_name"]).jld",
     "simulation_params", clean_simulation_params_for_jld(simulation_params),
     "raw_precoding_results", raw_precoding_results,
     "raw_assignment_results", raw_assignment_results)