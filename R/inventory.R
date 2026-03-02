#' Safety Stock
#'
#' Computes safety stock and its annual holding cost. The function annualizes
#' the holding cost using the length of the demand vector (e.g., 12 for monthly
#' demand spanning one year).
#'
#' @param demand numeric vector of demand per period (used to compute sigma_d via \code{sd()})
#' @param L numeric; lead time in same units as demand periods
#' @param k numeric; monthly (per-period) holding cost rate as a proportion of unit cost.
#'   For example, if the annual rate is 24\%, then k = 0.24 / 12 = 0.02 per month.
#' @param C numeric; unit cost (cost per item)
#' @param alpha numeric; stockout probability (provide \code{alpha} OR \code{service_level}, not both)
#' @param service_level numeric; service level = 1 - alpha
#'
#' @return A named list with:
#' \describe{
#'   \item{SS}{Safety stock quantity = Z * sigma_d * sqrt(L)}
#'   \item{annual_holding_cost}{Annual holding cost of safety stock = SS * k * C * length(demand)}
#' }
#'
#' @examples
#' demand <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)
#' SS(demand, L = 1, k = 0.02, C = 20, alpha = 0.05)
#'
#' @export
SS <- function(demand, L, k, C, alpha = NULL, service_level = NULL) {
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
  if (!is.numeric(k) || length(k) != 1 || k <= 0)
    stop("k must be a single positive number", call. = FALSE)
  if (!is.numeric(C) || length(C) != 1 || C <= 0)
    stop("C must be a single positive number", call. = FALSE)

  Z <- stats::qnorm(service_level)
  sigma_d <- stats::sd(demand)
  ss <- Z * sigma_d * sqrt(L)
  H_annual <- k * C * length(demand)

  list(SS = ss, annual_holding_cost = ss * H_annual)
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
#' ROP(demand, L = 1, k = 0.02, C = 20, alpha = 0.05)
#'
#' @export
ROP <- function(demand, L, k, C, alpha = NULL, service_level = NULL) {
  ss_result <- SS(demand, L, k, C, alpha = alpha, service_level = service_level)
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
#' Computes the classic EOQ and its associated Relevant Inventory Costs (RIC).
#' The holding cost is annualized as k * C * periods.
#'
#' @param R numeric; annual demand
#' @param S numeric; ordering cost per order
#' @param k numeric; monthly (per-period) holding cost rate as a proportion of unit cost.
#'   For example, if the annual rate is 24\%, then k = 0.24 / 12 = 0.02 per month.
#' @param C numeric; unit cost (cost per item)
#' @param periods numeric; number of periods per year (e.g., 12 for monthly data)
#'
#' @return A named list with:
#' \describe{
#'   \item{EOQ}{Economic order quantity = sqrt(2 * R * S / H_annual)}
#'   \item{RIC}{Relevant Inventory Costs = EOQ/2 * H_annual + R * S / EOQ}
#' }
#'
#' @examples
#' EOQ(R = 1200, S = 54, k = 0.02, C = 20, periods = 12)
#'
#' @export
EOQ <- function(R, S, k, C, periods) {
  if (!is.numeric(R) || length(R) != 1 || R <= 0)
    stop("R must be a single positive number", call. = FALSE)
  if (!is.numeric(S) || length(S) != 1 || S <= 0)
    stop("S must be a single positive number", call. = FALSE)
  if (!is.numeric(k) || length(k) != 1 || k <= 0)
    stop("k must be a single positive number", call. = FALSE)
  if (!is.numeric(C) || length(C) != 1 || C <= 0)
    stop("C must be a single positive number", call. = FALSE)
  if (!is.numeric(periods) || length(periods) != 1 || periods <= 0)
    stop("periods must be a single positive number", call. = FALSE)

  H_annual <- k * C * periods
  eoq <- sqrt(2 * R * S / H_annual)
  ric <- eoq / 2 * H_annual + R * S / eoq

  list(EOQ = eoq, RIC = ric)
}
