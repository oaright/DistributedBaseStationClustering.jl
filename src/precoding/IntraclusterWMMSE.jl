##########################################################################
# IntraclusterWMMSE
#
# This is a version of the original WMMSE algorithm from
# Shi, Razaviyayn, Luo, He, "An iteratively weighted MMSE approach to
# distributed sum-utility maximization for a MIMO interfering broadcast
# channel", IEEE Trans. Signal Process., vol. 59, no. 9, 4331-4340, 2011,
# which has been modified to take into account the intracluster
# interference. This is done by maximizing a lower bound, where Jensen's
# inequality has been applied to the logdet(E) term, w.r.t. the expectation
# of out-of-cluster interference.

immutable IntraclusterWMMSEState
    U::Array{Matrix{Complex128},1}
    V::Array{Matrix{Complex128},1}

    # utility-optimal weight
    Z::Array{Diagonal{Float64},1}

    # logdet(inv(E_full[k])) is the optimal rate for MS k, i.e. with full CSI-R.
    # (That is, E_full is the MMSE matrix.)
    E_full::Array{Diagonal{Float64},1}

    # logdet(inv(E_partial[k])) is a rate lower bound for MS k when the receive filter
    # is based on intercluster CSI-R only. It is _not_ assumed that the MS can
    # track all intracluster interference, and that is why this is a lower bound.
    E_partial::Array{Diagonal{Float64},1}
end

NaiveIntraclusterWMMSE(channel, network) =
    IntraclusterWMMSE(channel, network, robustness=false)
RobustIntraclusterWMMSE(channel, network) =
    IntraclusterWMMSE(channel, network, robustness=true)

function IntraclusterWMMSE(channel, network; robustness::Bool=true)
    assignment = get_assignment(network)

    K = get_no_MSs(network)
    Ps = get_transmit_powers(network)
    sigma2s = get_receiver_noise_powers(network)
    ds = get_no_streams(network); max_d = maximum(ds)
    alphas = get_user_priorities(network)

    aux_params = get_aux_precoding_params(network)
    @defaultize_param! aux_params "IntraclusterWMMSE:bisection_Gamma_cond" 1e10
    @defaultize_param! aux_params "IntraclusterWMMSE:bisection_singular_Gamma_mu_lower_bound" 1e-14
    @defaultize_param! aux_params "IntraclusterWMMSE:bisection_max_iters" 5e1
    @defaultize_param! aux_params "IntraclusterWMMSE:bisection_tolerance" 1e-3

    clustering_type = get_aux_assignment_param(network, "clustering_type")

    state = IntraclusterWMMSEState(
        Array(Matrix{Complex128}, K),
        initial_precoders(channel, Ps, sigma2s, ds, assignment, aux_params),
        Array(Diagonal{Float64}, K),
        Array(Diagonal{Float64}, K),
        Array(Diagonal{Float64}, K)
    )
    objective = Float64[]
    utilities = Array(Float64, K, max_d, aux_params["max_iters"])
    weighted_logdet_rates_full = Array(Float64, K, max_d, aux_params["max_iters"])
    weighted_logdet_rates_partial = Array(Float64, K, max_d, aux_params["max_iters"])
    allocated_power = Array(Float64, K, max_d, aux_params["max_iters"])

    iters = 0; conv_crit = Inf
    while iters < aux_params["max_iters"]
        update_MSs!(state, channel, Ps, sigma2s, assignment,
            clustering_type, robustness)
        iters += 1

        # Results after this iteration
        utilities[:,:,iters] = calculate_utilities(state, alphas)
        push!(objective, sum(utilities[:,:,iters]))
        weighted_logdet_rates_full[:,:,iters], weighted_logdet_rates_partial[:,:,iters] = calculate_weighted_logdet_rates(state, alphas)
        allocated_power[:,:,iters] = calculate_allocated_power(state)

        # Check convergence
        if iters >= 2
            conv_crit = abs(objective[end] - objective[end-1])/abs(objective[end-1])
            if conv_crit < aux_params["stop_crit"]
                Lumberjack.debug("IntraclusterWMMSE converged.",
                    [ :no_iters => iters,
                      :final_objective => objective[end],
                      :conv_crit => conv_crit,
                      :stop_crit => aux_params["stop_crit"],
                      :max_iters => aux_params["max_iters"] ]
                )
                break
            end
        end

        # Begin next iteration, unless the loop will end
        if iters < aux_params["max_iters"]
            update_BSs!(state, channel, Ps, alphas, assignment, aux_params,
                clustering_type, robustness)
        end
    end
    if iters == aux_params["max_iters"]
        Lumberjack.debug("IntraclusterWMMSE did NOT converge.",
            [ :no_iters => iters,
              :final_objective => objective[end],
              :conv_crit => conv_crit,
              :stop_crit => aux_params["stop_crit"],
              :max_iters => aux_params["max_iters"] ]
        )
    end

    results = PrecodingResults()
    if aux_params["output_protocol"] == :all_iterations
        results["objective"] = objective
        results["utilities"] = utilities
        results["weighted_logdet_rates_full"] = weighted_logdet_rates_full
        results["weighted_logdet_rates_partial"] = weighted_logdet_rates_partial
        results["allocated_power"] = allocated_power
    elseif aux_params["output_protocol"] == :final_iteration
        results["objective"] = objective[iters]
        results["utilities"] = utilities[:,:,iters]
        results["weighted_logdet_rates_full"] = weighted_logdet_rates_full[:,:,iters]
        results["weighted_logdet_rates_partial"] = weighted_logdet_rates_partial[:,:,iters]
        results["allocated_power"] = allocated_power[:,:,iters]
    end
    return results
end

function update_MSs!(state::IntraclusterWMMSEState,
    channel::SinglecarrierChannel, Ps, sigma2s, assignment,
    clustering_type, robustness)

    ds = [ size(state.V[k], 2) for k = 1:channel.K ]

    for i = 1:channel.I; for k in served_MS_ids(i, assignment)
        coordinators = coordinated_BS_ids(k, assignment)

        # Covariances
        Phi_full           = Hermitian(complex(sigma2s[k]*eye(channel.Ns[k]))) # both intercluster and intracluster channels
        Phi_partial_naive  = Hermitian(complex(sigma2s[k]*eye(channel.Ns[k]))) # intercluster instantaneous CSI-R; intracluster ignored
        Phi_partial_robust = Hermitian(complex(sigma2s[k]*eye(channel.Ns[k]))) # intercluster instantaneous CSI-R; intracluster statistical CSI-R

        # Intercluster CSI-R
        for j in coordinators; for l in served_MS_ids(j, assignment)
            Fkjl = channel.H[k,j]*state.V[l]
            Base.LinAlg.BLAS.herk!(Phi_full.uplo, 'N', complex(1.), Fkjl, complex(1.), Phi_full.S)
            Base.LinAlg.BLAS.herk!(Phi_partial_naive.uplo, 'N', complex(1.), Fkjl, complex(1.), Phi_partial_naive.S)
            Base.LinAlg.BLAS.herk!(Phi_partial_robust.uplo, 'N', complex(1.), Fkjl, complex(1.), Phi_partial_robust.S)
        end; end

        # Intracluster CSI-R (only applicable if we are using spectrum_sharing!)
        if clustering_type == :spectrum_sharing
            for j in setdiff(IntSet(1:channel.I), coordinators); for l in served_MS_ids(j, assignment)
                Base.LinAlg.BLAS.herk!(Phi_full.uplo, 'N', complex(1.), channel.H[k,j]*state.V[l], complex(1.), Phi_full.S)
                Phi_partial_robust += Hermitian(complex(channel.large_scale_fading_factor[k,j]^2*trace(state.V[l]'*state.V[l])*eye(channel.Ns[k])))
            end; end
        end

        # Desired channel
        Fiki = channel.H[k,i]*state.V[k]

        # Receivers and weights
        U_full = Phi_full\Fiki
        U_robust = Phi_partial_robust\Fiki
        if robustness
            state.U[k] = U_robust
        else
            U_naive = Phi_partial_naive\Fiki
            state.U[k] = U_naive
        end
        state.Z[k] = Diagonal(1./min(1, abs(diag((eye(ds[k]) - state.U[k]'*Fiki))))) # same structure regardless of robustness

        # Full CSI, i.e. intracluster CSI is estimated in a final training stage.
        # This is an achievable rate.
        state.E_full[k] = Diagonal(min(1, abs(diag(eye(ds[k]) - U_full'*Fiki))))

        # Partial CSI, i.e. intracluster CSI is _NOT_ estimated.
        # This is either a rate bound (if the receiver is aware that intracluster interference exists),
        # or an achievable rate (if the receiver is oblivious of the intracluster interference). Cf. Lapidoth1996.
        state.E_partial[k] = Diagonal(min(1, abs(diag(eye(ds[k]) - U_robust'*Fiki))))
    end; end
end

function update_BSs!(state::IntraclusterWMMSEState,
    channel::SinglecarrierChannel, Ps, alphas, assignment, aux_params,
    clustering_type, robustness)

    for i in active_BSs(assignment)
        coordinators = coordinated_MS_ids(i, assignment)

        # Covariance
        Gamma = Hermitian(complex(zeros(channel.Ms[i], channel.Ms[i])))
        for j = 1:channel.I; for l in served_MS_ids(j, assignment)
            if l in coordinators
                Gamma += Hermitian(alphas[l]*channel.H[l,i]'*(state.U[l]*state.Z[l]*state.U[l]')*channel.H[l,i])
            else
                # Take out-of-cluster interference into account if we are using
                # spectrum sharing, and we actually want to be robust against
                # this type of generated interference.
                if clustering_type == :spectrum_sharing && robustness
                    # Using vecnorm(.)^2 may generate NaNs here!
                    Gamma += Hermitian(complex(alphas[l]*channel.large_scale_fading_factor[l,i]^2*trace(state.U[l]'*state.U[l]*state.Z[l])*eye(channel.Ms[i])))
                    # Breaking version: Gamma += Hermitian(complex(alphas[l]*channel.large_scale_fading_factor[l,i]^2*vecnorm(state.U[l])^2*eye(channel.Ms[i])))
                end
            end
        end; end

        # Find optimal Lagrange multiplier
        mu_star, Gamma_eigen =
            optimal_mu(i, Gamma, state, channel, Ps, alphas, assignment, aux_params)

        # Precoders (reuse EVD)
        for k in served_MS_ids(i, assignment)
            state.V[k] = Gamma_eigen.vectors*Diagonal(1./(abs(Gamma_eigen.values) .+ mu_star))*Gamma_eigen.vectors'*channel.H[k,i]'*state.U[k]*state.Z[k]*alphas[k]
        end
    end
end

function optimal_mu(i, Gamma, state::IntraclusterWMMSEState,
    channel::SinglecarrierChannel, Ps, alphas, assignment, aux_params)

    # Build bisector function
    bis_M = Hermitian(complex(zeros(channel.Ms[i], channel.Ms[i])))
    for k in served_MS_ids(i, assignment)
        #bis_M += Hermitian(alphas[k]^2*channel.H[k,i]'*(state.U[k]*(state.Z[k]*state.Z[k]')*state.U[k]')*channel.H[k,i])
        Base.LinAlg.BLAS.herk!(bis_M.uplo, 'N', complex(1.), channel.H[k,i]'*state.U[k]*state.Z[k]*alphas[k], complex(1.), bis_M.S)
    end
    Gamma_eigen = eigfact(Gamma); Gamma_eigen_values = abs(Gamma_eigen.values)
    bis_JMJ_diag = abs(diag(Gamma_eigen.vectors'*bis_M*Gamma_eigen.vectors))
    f(mu) = sum(bis_JMJ_diag./((Gamma_eigen_values .+ mu).*(Gamma_eigen_values .+ mu)))

    # mu lower bound
    if maximum(Gamma_eigen_values)/minimum(Gamma_eigen_values) < aux_params["IntraclusterWMMSE:bisection_Gamma_cond"]
        # Gamma is invertible
        mu_lower = 0.
    else
        mu_lower = aux_params["IntraclusterWMMSE:bisection_singular_Gamma_mu_lower_bound"]
    end

    if f(mu_lower) <= Ps[i]
        # No bisection needed
        return mu_lower, Gamma_eigen
    else
        # mu upper bound
        mu_upper = sqrt(channel.Ms[i]/Ps[i]*maximum(bis_JMJ_diag)) - minimum(Gamma_eigen_values)
        if f(mu_upper) > Ps[i]
            Lumberjack.error("Power bisection: infeasible mu upper bound.")
        end

        no_iters = 0
        while no_iters < aux_params["IntraclusterWMMSE:bisection_max_iters"]
            conv_crit = (Ps[i] - f(mu_upper))/Ps[i]

            if conv_crit < aux_params["IntraclusterWMMSE:bisection_tolerance"]
                break
            else
                mu = (1/2)*(mu_lower + mu_upper)

                if f(mu) < Ps[i]
                    # New point feasible, replace upper point
                    mu_upper = mu
                else
                    # New point not feasible, replace lower point
                    mu_lower = mu
                end
            end

            no_iters += 1
        end

        if no_iters == aux_params["IntraclusterWMMSE:bisection_max_iters"]
            Lumberjack.warn("Power bisection: reached max iterations.")
        end

        # The upper point is always feasible, therefore we use it
        return mu_upper, Gamma_eigen
    end
end

function calculate_utilities(state::IntraclusterWMMSEState, alphas)
    K = length(state.V)
    ds = Int[ size(state.V[k], 2) for k = 1:K ]; max_d = maximum(ds)

    utilities = zeros(Float64, K, max_d)
    for k = 1:K; if ds[k] > 0
        r_utilities = alphas[k]*log2(max(1, abs(eigvals(state.Z[k]))))

        if ds[k] < max_d
            utilities[k,:] = cat(1, r_utilities, zeros(Float64, max_d - ds[k]))
        else
            utilities[k,:] = r_utilities
        end
    end; end

    return utilities
end
