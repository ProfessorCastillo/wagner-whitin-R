#' Wagner-Whitin Dynamic Lot Sizing Algorithm
#'
#' Computes the optimal lot-sizing schedule that minimizes total relevant
#' inventory costs (RIC) using the Wagner-Whitin forward algorithm.
#'
#' @param demand numeric vector of demand per period (length N)
#' @param S numeric; fixed ordering cost per order
#' @param k numeric; per-period holding cost rate (e.g., monthly rate = annual rate / 12)
#' @param C numeric; unit cost (cost per item). The per-period holding cost is k * C.
#'
#' @return An object of class \code{"WW"} with fields:
#' \describe{
#'   \item{RIC}{Relevant Inventory Costs (minimum ordering + holding cost)}
#'   \item{cost_matrix}{N x N cost matrix (rows = order period, columns = demand period covered through)}
#'   \item{schedule}{data.frame with order_period, covers_through, quantity}
#'   \item{demand}{original demand vector}
#'   \item{S}{ordering cost used}
#'   \item{k}{holding cost rate used}
#'   \item{C}{unit cost used}
#' }
#'
#' @examples
#' forecast <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)
#' result <- WW(forecast, S = 54, k = 0.02, C = 20)
#' print(result)
#' plot(result)
#'
#' @importFrom graphics barplot lines legend par axis mtext
#' @importFrom stats qnorm sd
#' @export
WW <- function(demand, S, k, C) {
  cl <- match.call()
  .validate_inputs(demand, S, k, C)

  H <- k * C
  build <- .build_cost_matrix(demand, S, H)
  sched <- .trace_schedule(build$cost_matrix, demand)

  result <- list(
    RIC = build$F_opt[length(demand)],
    cost_matrix = build$cost_matrix,
    schedule = sched,
    demand = demand,
    S = S,
    k = k,
    C = C,
    call = cl
  )
  class(result) <- "WW"
  result
}

#' Print a WW result
#'
#' @param x a WW object
#' @param ... additional arguments (ignored)
#'
#' @export
print.WW <- function(x, ...) {
  cat("Call:\n")
  print(x$call)
  cat("\nRIC:", x$RIC, "\n")
  cat("\nCost Matrix:\n")
  cat("[rows = order period, columns = demand period covered through]\n\n")
  cm <- round(x$cost_matrix, 2)
  dimnames(cm) <- NULL
  print(cm, na.print = "")
  cat("\nOptimal Schedule:\n")
  print(x$schedule, row.names = TRUE)
  invisible(x)
}

#' Plot a WW result
#'
#' Produces a bar chart of order quantities by period with ending inventory
#' overlaid as a connected line.
#'
#' @param x a WW object
#' @param ... additional arguments (ignored)
#'
#' @export
plot.WW <- function(x, ...) {
  N <- length(x$demand)

  # Build order quantity vector (0 for non-order periods)
  order_qty <- rep(0, N)
  order_qty[x$schedule$order_period] <- x$schedule$quantity

  # Compute ending inventory for each period
  ending_inv <- numeric(N)
  inv <- 0
  for (t in seq_len(N)) {
    inv <- inv + order_qty[t] - x$demand[t]
    ending_inv[t] <- inv
  }

  # Save and restore par
  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par))
  par(mar = c(5, 4, 4, 4) + 0.1)

  # Bar plot of order quantities
  bp <- barplot(order_qty, names.arg = seq_len(N),
                col = "steelblue", border = "steelblue",
                xlab = "Period", ylab = "Order Quantity",
                main = paste0("Wagner-Whitin Lot Sizing (RIC = ", x$RIC, ")"),
                ylim = c(0, max(c(order_qty, ending_inv)) * 1.15))

  # Overlay ending inventory line
  lines(bp, ending_inv, type = "o", col = "red", pch = 16, lwd = 2)

  legend("topleft",
         legend = c("Order Quantity", "Ending Inventory"),
         col = c("steelblue", "red"),
         pch = c(15, 16),
         lty = c(NA, 1),
         lwd = c(NA, 2),
         bty = "n")
}
