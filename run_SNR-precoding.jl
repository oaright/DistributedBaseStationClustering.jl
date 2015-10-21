#!/usr/bin/env julia

##########################################################################
# run_SNR-precoding.jl
#
# Performance as a function of transmit power, comparing different
# precoding methods.
##########################################################################

include("src/DistributedBaseStationClustering.jl")
using DistributedBaseStationClustering, CoordinatedPrecoding
using Compat, JLD

##########################################################################
# General settings
srand(973472333)
start_time = strftime("%Y%m%dT%H%M%S", time())

##########################################################################
# RandomLargeScaleNetwork
simulation_params = @compat Dict(
    "simulation_name" => "SNR-precoding_$(start_time)",
    "I" => 8, "Kc" => 1, "N" => 2, "M" => 4, "d" => 1,
    "Ndrops" => 10, "Nsim" => 20,
    "geography_size" => (1300.,1300.),
    "MS_serving_BS_distance" => Nullable{Float64}(),
    "assignment_methods" => [
        BranchAndBoundClustering,
    ],
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
    "aux_network_params" => @Compat.Dict(
        "num_coherence_symbols" => 2_700,
    ),
    "aux_assignment_params" => @Compat.Dict(
        "clustering_type" => :spectrum_sharing,
        "apply_overhead_prelog" => true,
        "IA_infeasible_negative_inf_utility" => true,
        "replace_E1_utility_with_lower_bound" => false,
    ),
    "aux_precoding_params" => @Compat.Dict(
        "initial_precoders" => "eigendirection",
        "stop_crit" => 1e-3,
        "max_iters" => 1000,
    ),
    "independent_variable" => (set_transmit_powers_dBm!, -50:10:0),
)
network =
    setup_random_large_scale_network(simulation_params["I"],
        simulation_params["Kc"], simulation_params["N"], simulation_params["M"],
        num_streams=simulation_params["d"],
        geography_size=simulation_params["geography_size"],
        MS_serving_BS_distance=simulation_params["MS_serving_BS_distance"])

raw_precoding_results, raw_assignment_results =
    simulate(network, simulation_params, loop_over=:precoding_methods)

println("-- Saving $(simulation_params["simulation_name"]) results")
save("$(simulation_params["simulation_name"]).jld",
     "simulation_params", clean_simulation_params_for_jld(simulation_params),
     "raw_precoding_results", raw_precoding_results,
     "raw_assignment_results", raw_assignment_results)
