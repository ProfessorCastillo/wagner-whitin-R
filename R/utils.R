# Internal helper functions for the Wagner-Whitin algorithm
# These are not exported.

#' Validate inputs for WW()
#' @param demand numeric vector of demand per period
#' @param S ordering cost
#' @param k per-period holding cost rate
#' @param C unit cost
#' @noRd
.validate_inputs <- function(demand, S, k, C) {
  if (!is.numeric(demand))
    stop("demand must be a numeric vector", call. = FALSE)
  if (any(is.na(demand)))
    stop("demand must not contain NA values", call. = FALSE)
  if (any(demand < 0))
    stop("demand must not contain negative values", call. = FALSE)
  if (length(demand) == 0)
    stop("demand must have at least one period", call. = FALSE)
  if (!is.numeric(S) || length(S) != 1 || S <= 0)
    stop("S must be a single positive number", call. = FALSE)
  if (!is.numeric(k) || length(k) != 1 || k <= 0)
    stop("k must be a single positive number", call. = FALSE)
  if (!is.numeric(C) || length(C) != 1 || C <= 0)
    stop("C must be a single positive number", call. = FALSE)
}

#' Build the cost matrix using the forward algorithm
#'
#' For each column j (period 1..N), for each row i (1..j):
#'   Cell[i,j] = F_{i-1} + S + sum(demand[k] * H * (k - i) for k in i..j)
#' where F_0 = 0 and F_j = min of column j.
#'
#' @param demand numeric vector
#' @param S ordering cost
#' @param H holding cost per unit per period
#' @return list with cost_matrix (N x N) and F_opt vector
#' @noRd
.build_cost_matrix <- function(demand, S, H) {
  N <- length(demand)
  CM <- matrix(NA_real_, nrow = N, ncol = N)
  F_opt <- numeric(N)

  for (j in seq_len(N)) {
    for (i in seq_len(j)) {
      F_prev <- if (i == 1) 0 else F_opt[i - 1]
      holding <- sum(demand[i:j] * H * (seq(i, j) - i))
      CM[i, j] <- F_prev + S + holding
    }
    F_opt[j] <- min(CM[seq_len(j), j])
  }

  list(cost_matrix = CM, F_opt = F_opt)
}

#' Trace the optimal schedule backward through the cost matrix
#'
#' 1. Start at column N, find row with which.min() -> last order period
#' 2. Jump left to column (order_period - 1), repeat
#' 3. Build data.frame with order_period, covers_through, quantity
#' Ties broken by which.min() (earliest order period).
#'
#' @param CM cost matrix (N x N)
#' @param demand numeric vector
#' @return data.frame with columns order_period, covers_through, quantity
#' @noRd
.trace_schedule <- function(CM, demand) {
  N <- ncol(CM)
  order_period <- integer(0)
  covers_through <- integer(0)
  quantity <- numeric(0)

  j <- N
  while (j >= 1) {
    i <- which.min(CM[seq_len(j), j])
    order_period <- c(i, order_period)
    covers_through <- c(j, covers_through)
    quantity <- c(sum(demand[i:j]), quantity)
    j <- i - 1
  }

  data.frame(
    order_period = order_period,
    covers_through = covers_through,
    quantity = quantity
  )
}
