#' Safety Stock
#'
#' Computes safety stock and its annual holding cost. The demand vector is
#' assumed to span one year (e.g., 12 monthly periods).
#'
#' @param demand numeric vector of demand per period (used to compute sigma_d via \code{sd()})
#' @param L numeric; lead time in same units as demand periods
#' @param H numeric; holding cost per unit per period
#' @param alpha numeric; stockout probability (provide \code{alpha} OR \code{service_level}, not both)
#' @param service_level numeric; service level = 1 - alpha
#'
#' @return A named list with:
#' \describe{
#'   \item{SS}{Safety stock quantity = Z * sigma_d * sqrt(L)}
#'   \item{annual_holding_cost}{Annual holding cost of safety stock = SS * H * N_periods}
#' }
#'
#' @examples
#' demand <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)
#' SS(demand, L = 2, H = 0.4, alpha = 0.05)
#'
#' @export
SS <- function(demand, L, H, alpha = NULL, service_level = NULL) {
  if (is.null(alpha) && is.null(service_level))
    stop("Provide either alpha or service_level", call. = FALSE)
  if (!is.null(alpha) && !is.null(service_level))
    stop("Provide either alpha or service_level, not both", call. = FALSE)

  if (!is.null(alpha)) {
    if (!is.numeric(alpha) || length(alpha) != 1 || alpha <= 0 || alpha >= 1)
      stop("alpha must be a single number between 0 and 1 (exclusive)", call. = FALSE)
    service_level <- 1 - alpha
  }

  if (!is.numeric(service_level) || length(service_level) != 1 ||
      service_level <= 0 || service_level >= 1)
    stop("service_level must be a single number between 0 and 1 (exclusive)", call. = FALSE)

  if (!is.numeric(demand) || any(is.na(demand)))
    stop("demand must be a numeric vector with no NAs", call. = FALSE)
  if (!is.numeric(L) || length(L) != 1 || L <= 0)
    stop("L must be a single positive number", call. = FALSE)
  if (!is.numeric(H) || length(H) != 1 || H <= 0)
    stop("H must be a single positive number", call. = FALSE)

  Z <- stats::qnorm(service_level)
  sigma_d <- stats::sd(demand)
  ss <- Z * sigma_d * sqrt(L)

  list(SS = ss, annual_holding_cost = ss * H * length(demand))
}

#' Reorder Point
#'
#' Computes the reorder point (ROP) and safety stock. Internally calls
#' \code{\link{SS}} to compute safety stock.
#'
#' @inheritParams SS
#'
#' @return A named list with:
#' \describe{
#'   \item{ROP}{Reorder point = SS + d_bar * L}
#'   \item{SS}{Safety stock}
#'   \item{annual_holding_cost}{Annual holding cost of safety stock}
#'   \item{d_bar}{Mean demand per period}
#'   \item{sigma_d}{Standard deviation of demand}
#' }
#'
#' @examples
#' demand <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)
#' ROP(demand, L = 2, H = 0.4, alpha = 0.05)
#'
#' @export
ROP <- function(demand, L, H, alpha = NULL, service_level = NULL) {
  ss_result <- SS(demand, L, H, alpha = alpha, service_level = service_level)
  d_bar <- mean(demand)
  sigma_d <- stats::sd(demand)

  list(
    ROP = ss_result$SS + d_bar * L,
    SS = ss_result$SS,
    annual_holding_cost = ss_result$annual_holding_cost,
    d_bar = d_bar,
    sigma_d = sigma_d
  )
}

#' Economic Order Quantity
#'
#' Computes the classic EOQ formula: \code{sqrt(2 * R * S / H)}.
#'
#' @param R numeric; annual demand
#' @param S numeric; ordering cost per order
#' @param H numeric; holding cost per unit per period
#'
#' @return numeric; the economic order quantity
#'
#' @examples
#' EOQ(R = 1200, S = 54, H = 0.4)
#'
#' @export
EOQ <- function(R, S, H) {
  if (!is.numeric(R) || length(R) != 1 || R <= 0)
    stop("R must be a single positive number", call. = FALSE)
  if (!is.numeric(S) || length(S) != 1 || S <= 0)
    stop("S must be a single positive number", call. = FALSE)
  if (!is.numeric(H) || length(H) != 1 || H <= 0)
    stop("H must be a single positive number", call. = FALSE)

  sqrt(2 * R * S / H)
}
