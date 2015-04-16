vs_kmh = linspace(5, 80, 7) # km/h
vs = vs_kmh*(1e3/3600) # m/s

fds = vs/(λ*Wc)
Ls = 1./(2*fds);

simulation_params["independent_variable"] = ((n, v) -> set_aux_network_param!(n, v, "no_coherence_symbols"), Ls)
simulation_params["aux_independent_variables"] = [ ((n, v) -> set_transmit_powers_dBm!(n, v), [-30]) ]
