# ---------- Input validation ----------

test_that("WW rejects non-numeric demand", {
  expect_error(WW("abc", 54, 0.02, 20), "demand must be a numeric vector")
})

test_that("WW rejects demand with NA", {
  expect_error(WW(c(1, NA, 3), 54, 0.02, 20), "demand must not contain NA")
})

test_that("WW rejects negative demand", {
  expect_error(WW(c(1, -2, 3), 54, 0.02, 20), "demand must not contain negative")
})

test_that("WW rejects non-positive S", {
  expect_error(WW(c(10, 20), 0, 0.02, 20), "S must be a single positive number")
  expect_error(WW(c(10, 20), -1, 0.02, 20), "S must be a single positive number")
})

test_that("WW rejects non-positive k", {
  expect_error(WW(c(10, 20), 54, 0, 20), "k must be a single positive number")
  expect_error(WW(c(10, 20), 54, -1, 20), "k must be a single positive number")
})

test_that("WW rejects non-positive C", {
  expect_error(WW(c(10, 20), 54, 0.02, 0), "C must be a single positive number")
  expect_error(WW(c(10, 20), 54, 0.02, -1), "C must be a single positive number")
})

# ---------- Course example (N = 12) ----------

test_that("Course example: RIC = 501.2", {
  forecast <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)
  result <- WW(forecast, S = 54, k = 0.02, C = 20)
  expect_equal(result$RIC, 501.2)
})

test_that("Course example: specific cell values", {
  forecast <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)
  result <- WW(forecast, S = 54, k = 0.02, C = 20)
  expect_equal(result$cost_matrix[1, 1], 54)
  expect_equal(result$cost_matrix[1, 3], 88.4)
  expect_equal(result$cost_matrix[3, 3], 132.8)
})

test_that("Course example: lower triangle is NA", {
  forecast <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)
  result <- WW(forecast, S = 54, k = 0.02, C = 20)
  for (i in 2:12) {
    for (j in 1:(i - 1)) {
      expect_true(is.na(result$cost_matrix[i, j]))
    }
  }
})

test_that("Course example: schedule matches expected order periods", {
  forecast <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)
  result <- WW(forecast, S = 54, k = 0.02, C = 20)
  expect_equal(result$schedule$order_period, c(1, 4, 5, 7, 9, 10, 11))
  expect_equal(result$schedule$covers_through, c(3, 4, 6, 8, 9, 10, 12))
  expect_equal(result$schedule$quantity, c(84, 130, 283, 140, 124, 160, 279))
})

# ---------- Hillier example (N = 4) ----------

test_that("Hillier example: RIC = 4.8", {
  result <- WW(c(3, 2, 3, 2), S = 2, k = 0.1, C = 2)
  expect_equal(result$RIC, 4.8)
})

test_that("Hillier example: which.min selects single-order solution", {
  result <- WW(c(3, 2, 3, 2), S = 2, k = 0.1, C = 2)
  # which.min picks the first minimum (row 1), so single order covers all 4 periods
  expect_equal(nrow(result$schedule), 1)
  expect_equal(result$schedule$order_period, 1)
  expect_equal(result$schedule$covers_through, 4)
  expect_equal(result$schedule$quantity, 10)
})

# ---------- Edge cases ----------

test_that("Single period: one order, RIC = S", {
  result <- WW(5, S = 10, k = 0.5, C = 2)
  expect_equal(result$RIC, 10)
  expect_equal(nrow(result$schedule), 1)
  expect_equal(result$schedule$order_period, 1)
  expect_equal(result$schedule$quantity, 5)
})

test_that("Zero-demand periods are handled", {
  result <- WW(c(10, 0, 0, 10), S = 5, k = 0.5, C = 2)
  expect_true(is.numeric(result$RIC))
  expect_true(all(result$schedule$quantity >= 0))
})

test_that("WW returns correct class", {
  result <- WW(c(10, 20), S = 5, k = 0.25, C = 2)
  expect_s3_class(result, "WW")
})

test_that("WW echoes inputs", {
  demand <- c(10, 62, 12)
  result <- WW(demand, S = 54, k = 0.02, C = 20)
  expect_equal(result$demand, demand)
  expect_equal(result$S, 54)
  expect_equal(result$k, 0.02)
  expect_equal(result$C, 20)
})

# ---------- S3 methods ----------

test_that("print.WW returns invisible(x)", {
  result <- WW(c(10, 20, 30), S = 5, k = 0.25, C = 2)
  out <- capture.output(ret <- print(result))
  expect_identical(ret, result)
})

test_that("print output contains key sections", {
  result <- WW(c(10, 20, 30), S = 5, k = 0.25, C = 2)
  out <- capture.output(print(result))
  combined <- paste(out, collapse = "\n")
  expect_true(grepl("Call:", combined))
  expect_true(grepl("RIC:", combined))
  expect_true(grepl("Cost Matrix:", combined))
  expect_true(grepl("Optimal Schedule:", combined))
})

test_that("plot.WW does not error", {
  result <- WW(c(10, 62, 12, 130), S = 54, k = 0.02, C = 20)
  expect_no_error(plot(result))
})
