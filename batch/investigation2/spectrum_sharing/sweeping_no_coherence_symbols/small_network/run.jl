#!/usr/bin/env julia

SRAND_SEED = 938327343

include(joinpath(dirname(@__FILE__), "../../../../../src/LongtermIAClustering.jl"))
using LongtermIAClustering, CoordinatedPrecoding
using Compat, JLD

include(joinpath(dirname(@__FILE__), "../../../simulation_params.jl"))
include(joinpath(dirname(@__FILE__), "../../../simulation_params-assignment_methods.jl"))
include(joinpath(dirname(@__FILE__), "../../../simulation_params-small_network.jl"))
include(joinpath(dirname(@__FILE__), "../../../simulation_params-num_coherence_symbols.jl"))
include(joinpath(dirname(@__FILE__), "../../../plot_params-assignment_methods.jl"))

##########################################################################
# Plot setup
for p in (plot_params_instantaneous_full_sumrate, plot_params_instantaneous_partial_sumrate, plot_params_instantaneous_LB_sumrate, plot_params_longterm_sumrate, plot_params_longterm_num_utility_calculations, plot_params_longterm_num_clusters)
    p["axes"][:xlabel] = "MS speed [km/h]"
    p["xvals"] = vs_kmh
end

##########################################################################
# Simulation (MinWLI)
start_time = strftime("%Y%m%dT%H%M%S", time())

srand(SRAND_SEED)
simulation_params["simulation_name"] = "SNR-small_network-assignment-MinWLI_$(start_time)"
simulation_params["precoding_methods"] = [ RobustIntraclusterLeakageMinimization ]
network =
    setup_random_large_scale_network(simulation_params["I"],
        simulation_params["Kc"], simulation_params["N"], simulation_params["M"],
        num_streams=simulation_params["d"],
        geography_size=simulation_params["geography_size"],
        MS_serving_BS_distance=simulation_params["MS_serving_BS_distance"])
raw_precoding_results1, raw_assignment_results1 =
    simulate(network, simulation_params, loop_over=:assignment_methods)

processed_results = postprocess(raw_precoding_results1, simulation_params, plot_params_instantaneous_full_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_full_sumrate)
processed_results = postprocess(raw_precoding_results1, simulation_params, plot_params_instantaneous_partial_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_partial_sumrate)
processed_results = postprocess(raw_precoding_results1, simulation_params, plot_params_instantaneous_LB_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_LB_sumrate)

println("-- Saving $(simulation_params["simulation_name"]) results")
save("$(simulation_params["simulation_name"]).jld",
     "simulation_params", clean_simulation_params_for_jld(simulation_params),
     "raw_precoding_results", raw_precoding_results1,
     "raw_assignment_results", raw_assignment_results1)

##########################################################################
# Generic plots
simulation_params["simulation_name"] = "SNR-small_network-assignment_$(start_time)"
for p in (plot_params_longterm_sumrate, plot_params_longterm_num_utility_calculations, plot_params_longterm_num_clusters)
    processed_results = postprocess(raw_assignment_results1, simulation_params, p)
    plot(processed_results, simulation_params, p)
end

##########################################################################
# Simulation (WMMSE)
srand(SRAND_SEED)
simulation_params["simulation_name"] = "SNR-small_network-assignment-WMMSE_$(start_time)"
simulation_params["precoding_methods"] = [ RobustIntraclusterWMMSE ]
network =
    setup_random_large_scale_network(simulation_params["I"],
        simulation_params["Kc"], simulation_params["N"], simulation_params["M"],
        num_streams=simulation_params["d"],
        geography_size=simulation_params["geography_size"],
        MS_serving_BS_distance=simulation_params["MS_serving_BS_distance"])
raw_precoding_results2, raw_assignment_results2 =
    simulate(network, simulation_params, loop_over=:assignment_methods)

processed_results = postprocess(raw_precoding_results2, simulation_params, plot_params_instantaneous_full_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_full_sumrate)
processed_results = postprocess(raw_precoding_results2, simulation_params, plot_params_instantaneous_partial_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_partial_sumrate)
processed_results = postprocess(raw_precoding_results2, simulation_params, plot_params_instantaneous_LB_sumrate)
plot(processed_results, simulation_params, plot_params_instantaneous_LB_sumrate)

println("-- Saving $(simulation_params["simulation_name"]) results")
save("$(simulation_params["simulation_name"]).jld",
     "simulation_params", clean_simulation_params_for_jld(simulation_params),
     "raw_precoding_results", raw_precoding_results2,
     "raw_assignment_results", raw_assignment_results2)
