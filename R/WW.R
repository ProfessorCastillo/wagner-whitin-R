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
  par(mfrow = c(1, 2), oma = c(0, 0, 2, 0))

  # Left panel: order quantities
  barplot(order_qty, names.arg = seq_len(N),
          col = "steelblue", border = "steelblue",
          xlab = "Period", ylab = "Order Quantity",
          main = "Order Quantities")

  # Right panel: ending inventory
  bp <- barplot(ending_inv, names.arg = seq_len(N),
                col = "red", border = "red",
                xlab = "Period", ylab = "Ending Inventory",
                main = "Ending Inventory")

  # Shared title
  mtext(paste0("Wagner-Whitin Lot Sizing (RIC = ", x$RIC, ")"),
        outer = TRUE, cex = 1.2)
}

#' Export WW results to Excel
#'
#' Writes two tabs to an .xlsx file: the cost matrix and a period-by-period
#' ordering schedule showing beginning inventory, replenishment, demand, and
#' ending inventory. Requires the \pkg{openxlsx} package.
#'
#' @param x a WW object
#' @param file character; path to the output .xlsx file
#'
#' @examples
#' \dontrun{
#' result <- WW(c(10, 62, 12, 130), S = 54, k = 0.02, C = 20)
#' export_xlsx(result, "wagner_whitin.xlsx")
#' }
#'
#' @export
export_xlsx <- function(x, file) {
  if (!inherits(x, "WW"))
    stop("x must be a WW object", call. = FALSE)
  if (!requireNamespace("openxlsx", quietly = TRUE))
    stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')",
         call. = FALSE)

  N <- length(x$demand)

  # Compute period-by-period inventory
  order_qty <- rep(0, N)
  order_qty[x$schedule$order_period] <- x$schedule$quantity

  beg_inv <- numeric(N)
  end_inv <- numeric(N)
  inv <- 0
  for (t in seq_len(N)) {
    beg_inv[t] <- inv
    inv <- inv + order_qty[t] - x$demand[t]
    end_inv[t] <- inv
  }

  wb <- openxlsx::createWorkbook()

  # --- Sheet 1: Cost Matrix ---
  openxlsx::addWorksheet(wb, "Cost Matrix")
  cm_df <- data.frame(Period = seq_len(N), x$cost_matrix, check.names = FALSE)
  colnames(cm_df) <- c("Period", seq_len(N))
  openxlsx::writeData(wb, "Cost Matrix", cm_df)

  # --- Sheet 2: Ordering Schedule ---
  openxlsx::addWorksheet(wb, "Ordering Schedule")

  # Build the schedule data frame (4 rows x N+2 columns)
  sched_df <- data.frame(
    `--` = c("Beginning Inventory", "Replenishment Quantity", "Demand",
             "Ending Inventory"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  for (t in seq_len(N)) {
    sched_df[[as.character(t)]] <- c(beg_inv[t], order_qty[t], x$demand[t], end_inv[t])
  }
  sched_df[["Total"]] <- c(NA_real_, sum(order_qty), sum(x$demand), sum(end_inv))

  openxlsx::writeData(wb, "Ordering Schedule", sched_df)

  # Overwrite Beginning Inventory total with "--"
  openxlsx::writeData(wb, "Ordering Schedule", "--",
                       startRow = 2, startCol = N + 2)

  openxlsx::saveWorkbook(wb, file, overwrite = TRUE)
  invisible(file)
}
