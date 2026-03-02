# ---------- SS (Safety Stock) ----------

test_that("SS with alpha gives correct result", {
  demand <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)
  result <- SS(demand, L = 2, H = 0.4, alpha = 0.05)
  Z <- qnorm(0.95)
  sigma_d <- sd(demand)
  expected_ss <- Z * sigma_d * sqrt(2)
  expect_equal(result$SS, expected_ss)
  expect_equal(result$annual_holding_cost, expected_ss * 0.4 * 12)
})

test_that("SS with service_level gives same result as alpha", {
  demand <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)
  r1 <- SS(demand, L = 2, H = 0.4, alpha = 0.05)
  r2 <- SS(demand, L = 2, H = 0.4, service_level = 0.95)
  expect_equal(r1$SS, r2$SS)
  expect_equal(r1$annual_holding_cost, r2$annual_holding_cost)
})

test_that("SS errors when both alpha and service_level given", {
  expect_error(SS(1:12, 1, 1, alpha = 0.05, service_level = 0.95),
               "not both")
})

test_that("SS errors when neither alpha nor service_level given", {
  expect_error(SS(1:12, 1, 1), "either alpha or service_level")
})

test_that("SS errors for invalid alpha", {
  expect_error(SS(1:12, 1, 1, alpha = 0), "between 0 and 1")
  expect_error(SS(1:12, 1, 1, alpha = 1), "between 0 and 1")
  expect_error(SS(1:12, 1, 1, alpha = -0.5), "between 0 and 1")
})

test_that("SS errors for negative L", {
  expect_error(SS(1:12, L = -1, H = 1, alpha = 0.05), "L must be a single positive")
})

# ---------- ROP (Reorder Point) ----------

test_that("ROP equals SS + d_bar * L", {
  demand <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)
  result <- ROP(demand, L = 2, H = 0.4, alpha = 0.05)
  ss_result <- SS(demand, L = 2, H = 0.4, alpha = 0.05)
  expect_equal(result$ROP, ss_result$SS + mean(demand) * 2)
  expect_equal(result$SS, ss_result$SS)
  expect_equal(result$d_bar, mean(demand))
  expect_equal(result$sigma_d, sd(demand))
})

test_that("ROP annual_holding_cost matches SS", {
  demand <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)
  rop_result <- ROP(demand, L = 2, H = 0.4, service_level = 0.95)
  ss_result <- SS(demand, L = 2, H = 0.4, service_level = 0.95)
  expect_equal(rop_result$annual_holding_cost, ss_result$annual_holding_cost)
})

# ---------- EOQ ----------

test_that("EOQ computes sqrt(2RS/H)", {
  result <- EOQ(R = 1200, S = 54, H = 0.4)
  expect_equal(result, sqrt(2 * 1200 * 54 / 0.4))
})

test_that("EOQ textbook example", {
  # R=1000, S=10, H=2 -> sqrt(2*1000*10/2) = sqrt(10000) = 100
  expect_equal(EOQ(R = 1000, S = 10, H = 2), 100)
})

test_that("EOQ errors for non-positive inputs", {
  expect_error(EOQ(R = 0, S = 54, H = 0.4), "R must be a single positive")
  expect_error(EOQ(R = 1200, S = -1, H = 0.4), "S must be a single positive")
  expect_error(EOQ(R = 1200, S = 54, H = 0), "H must be a single positive")
})
