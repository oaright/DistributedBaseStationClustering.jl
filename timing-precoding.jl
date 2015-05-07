#!/usr/bin/env julia

##########################################################################
# timing-precoding.jl
#
# Timing for cluster precoding methods
##########################################################################

include("src/IAClustering.jl")
using IAClustering, CoordinatedPrecoding
using HDF5, JLD

##########################################################################
# General settings
srand(973472333)

##########################################################################
# Indoors network
simulation_params = [
    "I" => 8, "Kc" => 1, "N" => 2, "M" => 2,
    "d" => 1,
    "Ntest" => 100,
    "geography_size" => (1500.,1500.),
    "MS_serving_BS_distance" => nothing,
    "assignment_methods" => [ BranchAndBoundClustering ],
    "precoding_methods" => [
        RobustIntraclusterWMMSE,
        NaiveIntraclusterWMMSE,

        RobustIntraclusterLeakageMinimization,
        NaiveIntraclusterLeakageMinimization,

        RobustChen2014_MaxSINR,
        NaiveChen2014_MaxSINR,

        Shi2011_WMMSE,
        Eigenprecoding,
    ],
    "aux_network_params" => [
        "no_coherence_symbols" => 2500,
    ],
    "aux_assignment_params" => [
        "clustering_type" => :spectrum_sharing,
        "apply_overhead_prelog" => true,
        "IA_infeasible_negative_inf_utility" => false,
        "replace_E1_utility_with_lower_bound" => false,

        "BranchAndBoundClustering:bracket_E1_in_bound" => true,
    ],
    "aux_precoding_params" => [
        "initial_precoders" => "eigendirection",
        "stop_crit" => 0.,
        "max_iters" => 100,
    ],
]
network =
    setup_random_large_scale_network(simulation_params["I"],
        simulation_params["Kc"], simulation_params["N"], simulation_params["M"],
        no_streams=simulation_params["d"],
        geography_size=simulation_params["geography_size"],
        MS_serving_BS_distance=simulation_params["MS_serving_BS_distance"])

timing(network, simulation_params, loop_over=:precoding_methods)
