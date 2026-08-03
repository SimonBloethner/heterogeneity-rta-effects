# =============================================================================
# Gravity Model Functions - FUNCTIONS ONLY, NO EXECUTION
# =============================================================================

exports <- function(t_1msig, E, p, P, sig) {
  p_mat <- matrix(rep(p, times = nrow(t_1msig)), ncol = nrow(t_1msig))
  P_mat <- matrix(rep(P, each = ncol(t_1msig)), ncol = ncol(t_1msig))
  E_mat <- matrix(rep(E, each = ncol(t_1msig)), ncol = ncol(t_1msig))
  (p_mat / P_mat)^(1 - sig) * t_1msig * E_mat
}

price_index <- function(t_1msig, p, sig) {
  p_mat <- matrix(rep(p, times = nrow(t_1msig)), ncol = nrow(t_1msig))
  (apply(p_mat^(1 - sig) * t_1msig, 2, sum))^(1 / (1 - sig))
}

price_prod <- function(Y, t_1msig, E, P, sig) {
  P_mat <- matrix(rep(P, each = ncol(t_1msig)), ncol = ncol(t_1msig))
  E_mat <- matrix(rep(E, each = ncol(t_1msig)), ncol = ncol(t_1msig))
  (Y / (apply((1 / P_mat)^(1 - sig) * t_1msig * E_mat, 1, sum)))^(1 / (1 - sig))
}


# Solve equilibrium - requires df and params in calling environment
solve_gravity_single_year <- function(cost_eq, df_year, params, verbose = FALSE, return_equilibrium = FALSE) {

  if (length(cost_eq) != nrow(df_year)) {
    stop(sprintf("cost_eq length (%d) doesn't match df_year rows (%d)", length(cost_eq), nrow(df_year)))
  }

  t <- data.frame(
    iso_x = df_year$iso_x,
    iso_i = df_year$iso_i,
    year = df_year$year,
    cost = cost_eq
  )

  t <- t[(t$iso_i %in% unique(t$iso_x)) & (t$iso_x %in% unique(t$iso_i)), ]

  df_t <- df_year
  df_t <- df_t[(df_t$iso_i %in% unique(df_t$iso_x)) & (df_t$iso_x %in% unique(df_t$iso_i)), ]

  Y_t <- aggregate(df_t$trade, by = list(df_t$year, df_t$iso_x), FUN = sum)
  E_t <- aggregate(df_t$trade, by = list(df_t$year, df_t$iso_i), FUN = sum)

  keep <- intersect(Y_t$Group.2[Y_t$x != 0], E_t$Group.2[E_t$x != 0])

  Y_t <- Y_t[Y_t$Group.2 %in% keep, ]
  E_t <- E_t[E_t$Group.2 %in% keep, ]

  df_t <- df_t[(df_t$iso_i %in% keep) & (df_t$iso_x %in% keep), ]

  t <- t[(t$iso_i %in% keep) & (t$iso_x %in% keep), ]

  dict <- data.frame(iso = unique(t$iso_x), number = 1:length(unique(t$iso_x)))

  t <- merge(t, dict, by.x = "iso_x", by.y = "iso")
  t <- merge(t, dict, by.x = "iso_i", by.y = "iso")
  names(t)[(ncol(t) - 1):ncol(t)] <- c("nbr_ex", "nbr_im")

  t_mat <- matrix(NA, nrow = length(unique(t$iso_x)), ncol = length(unique(t$iso_i)))
  t_mat[as.matrix(t[, c("nbr_ex", "nbr_im")])] <- t$cost

  P <- rep(1, length(unique(df_t$iso_i)))
  p_small <- rep(1, length(unique(df_t$iso_i)))
  eps <- rep(1e-6, length(unique(df_t$iso_i)))
  diff_p <- rep(10, length(unique(df_t$iso_i)))
 

  iter <- 0
  while (any(diff_p > eps)) {
    X <- exports(t_1msig = t_mat, E = E_t[, 3], p = p_small, P = P, sig = params$sig)
    P <- price_index(t_1msig = t_mat, p = p_small, sig = params$sig)
    p_small_1 <- price_prod(Y = Y_t[, 3], t_1msig = t_mat, E = E_t[, 3], P = P, sig = params$sig)
    p_small_1[which(dict[, 1] == "USA")] <- 1

    diff_p <- abs(p_small - p_small_1)
    p_small <- p_small_1
    iter <- iter + 1
  }

  if (verbose) {
    if (iter >= 1000) {
      cat(sprintf("  Warning: did not converge in %d iterations\n", 1000))
    } else {
      cat(sprintf("  Converged in %d iterations\n", iter))
    }
  }

  # Convert X matrix to data frame with country identifiers
  # This preserves which flow corresponds to which country pair
  trade_results <- data.frame(
    year = df_year$year[1],
    exporter = rep(dict$iso, times = nrow(dict)),
    importer = rep(dict$iso, each = nrow(dict)),
    trade = as.vector(X)
  )

  # Filter to positive flows only
  trade_results <- trade_results[trade_results$trade > 0, ]

  # Return based on return_equilibrium flag
  if (return_equilibrium) {
    # Return both trade results and equilibrium parameters
    return(list(
      trade = trade_results,
      equilibrium = list(
        P = P,           # Inward multilateral resistance (price index)
        p = p_small,     # Outward multilateral resistance (producer prices)
        Y = Y_t[, 3],    # Output by country
        E = E_t[, 3],    # Expenditure by country
        dict = dict,     # Country number mapping
        sig = params$sig # Elasticity of substitution
      )
    ))
  } else {
    # Backward compatibility: return only trade results
    return(trade_results)
  }
}