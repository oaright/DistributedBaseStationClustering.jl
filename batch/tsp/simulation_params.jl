# Default values
const fc = 2e9 # GHz
const Wc = 300e3 # kHz
const c = 300e6 # m/s
const λ = c/fc # m
const v_kmh = 30 # km/h
const v = v_kmh*(1e3/3600) # m/s
const fd = v/(λ*Wc)
const num_coherence_symbols = 1/(2*fd)
const beta_network_sdma = 0.66

const design_ISD = 500
const BS_density = sqrt(3)/2*design_ISD^2 # BSs per m^2, for hexagonal cells
const I = 12; const Kc = 2
const M = 8; const N = 2; const d = 1
const geography_width = sqrt(I*BS_density)
const MS_serving_BS_distance = Nullable(150.) # geography_width/10. = 161.1854897735313

const SNR_dB = 20

const Ndrops = 10
const Nsim = 10

const stop_crit = 1e-2
const max_iters = 1000

simulation_params = [
    "Ndrops" => Ndrops, "Nsim" => Nsim,
    "I" => I, "Kc" => Kc,
    "M" => M, "N" => N, "d" => d,
    "geography_size" => (geography_width, geography_width),
    "MS_serving_BS_distance" => MS_serving_BS_distance,
    "aux_network_params" => Dict{ASCIIString, Any}(),
    "aux_assignment_params" => [
        "max_num_MSs_per_BS" => Kc,

        "BranchAndBoundClustering:branching_rule" => :dfs,
        "BranchAndBoundClustering:max_abs_optimality_gap" => 0.,
        "BranchAndBoundClustering:max_rel_optimality_gap" => 0.,
        "BranchAndBoundClustering:E1_bound_in_rate_bound" => false,
        "BranchAndBoundClustering:store_evolution" => false,

        "CoalitionFormationClustering:search_order" => :lexicographic,
        "CoalitionFormationClustering:stability_type" => :individual,
        "CoalitionFormationClustering:search_budget" => 100,
        "CoalitionFormationClustering:use_history" => true,
        "CoalitionFormationClustering:starting_point" => :singletons,
    ],
    "aux_precoding_params" => [
        "initial_precoders" => "eigendirection",
        "stop_crit" => stop_crit,
        "max_iters" => max_iters,
    ],
]
