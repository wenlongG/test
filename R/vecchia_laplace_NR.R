### Vecchia-Laplace approximation using efficient CPP packages ###


#####################################################################
######################    Vecchia + Laplace     #####################
#####################################################################

# algorithm to find latent GP for non-gaussian likelihood
calculate_posterior_VL = function(vecchia.approx, likelihood_model, covparms, max.iter=50, convg = 1e-6, return_all = FALSE){
  # pull out constants for readability
  z = likelihood_model$z
  locs = likelihood_model$locs
  # pull out score and second derivative for readability
  ell_dbl_prime = likelihood_model$hess
  ell_prime = likelihood_model$score

  # for logging purposes, output scenario
  l_type = likelihood_model$type
  log_comment = paste("Running VL-NR for",l_type, "with _ nbrs and sample size", length(z) )
  message(log_comment)

  # record duration of NR
  t_start = Sys.time()

  # init latent variable
  y_o = rep(1, length(z))
  convgd = FALSE
  tot_iters = max.iter
  for( i in 1:max.iter){
    y_prev = y_o    # save y_prev for convergence test
    D_inv = ell_dbl_prime(y_o, z)
    D = solve(D_inv)
    u = ell_prime(y_o,z)
    pseudo.data = D %*% u + y_o
    nuggets = diag(D)
    # Update the pseudo data stored in the approximation
    vecchia.approx$zord=pseudo.data[vecchia.approx$ord]
    # Update U matrix with new nuggets, make the prediction
    U=createU(vecchia.approx,covparms,nuggets)
    V.ord=U2V(U,vecchia.approx)
    vecchia.mean=vecchia_mean(vecchia.approx,U,V.ord)
    y_o = vecchia.mean$mu.obs
    if (max(abs(y_o-y_prev))<convg){
      convgd = TRUE
      tot_iters = i
      break
    }
  }
  t_end = Sys.time()
  LV_time = as.double(difftime(t_end, t_start, units = "secs"))
  if(return_all){
    # return additional information if needed
    orig.order=order(vecchia.approx$ord)
    vec_likelihood = vecchia_likelihood(vecchia.approx,covparms,nuggets)
    W = as.matrix(rev.mat(V.ord%*%t(V.ord))[orig.order,orig.order])
    return (list("mean" = y_o, "sd" =sqrt(diag(solve(W))), "iter"=tot_iters,
                 "cnvgd" = convgd, "D" = D, "t"=pseudo.data, "V"=V.ord,
                 "W" = W, "vec_lh"=vec_likelihood, "runtime" = LV_time))
  }
  return (list("mean" = y_o, "cnvgd" = convgd, "iter" = tot_iters))
}



#####################################################################
######################    Laplace + True Covar ######################
#####################################################################


calculate_posterior_laplace = function(likelihood_model, C, convg = 1e-6, return_all = FALSE){
  l_type = likelihood_model$type
  locsord = likelihood_model$locs
  z = likelihood_model$z
  ell_dbl_prime = likelihood_model$hess
  ell_prime = likelihood_model$score
  log_comment = paste("Running Laplace for",l_type, "with sample size", length(z) )
  message(log_comment)

  C_inv = solve(C)

  y_o = rep(1,length(z))
  tot_iters=0
  # begin NR iteration
  for( i in 1:50){
    #b= exp(y_o) #scale, g''(y)
    D_inv = ell_dbl_prime(y_o, z)
    D = solve(D_inv)  # d is diagonal (hessian), cheap to invert
    u =  ell_prime(y_o,z)
    t = D%*%u+y_o
    W=D_inv+C_inv
    y_prev=y_o
    y_o = solve(W , D_inv) %*% t
    if (max(abs(y_o-y_prev))<convg){
      tot_iters = i
      break
    }
  } # end iterate

  if(return_all){
    # Caclulating sd is expensive, avoid for fair comparison
    sd_posterior = sqrt(diag(solve(W)))
    return (list("mean" = y_o, "W"=W,"sd" = sd_posterior, "iter"=tot_iters, "C"=C, "t" = t, "D" = D))
  }
  return (list("mean" = y_o, "W"=W, "iter"=tot_iters))
}


