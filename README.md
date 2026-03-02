# wagnerwhitin

An R package implementing the Wagner-Whitin dynamic lot-sizing algorithm, plus common inventory functions (Safety Stock, Reorder Point, EOQ). Built for undergraduate supply chain courses at The Ohio State University.

## Installation

```r
# install.packages("devtools")
devtools::install_github("ProfessorCastillo/wagner-whitin-R")
library(wagnerwhitin)
```

## Quick Start

```r
# Course example: 12-period demand
S <- 54
k <- 0.02
C <- 20
H <- k * C  # 0.40

forecast <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)
result <- WW(forecast, S, H)
result
```

Output:

```
Call:
WW(demand = forecast, S = 54, H = 0.4)

RIC: 501.2

Cost Matrix:
[rows = order period, columns = demand period covered through]

      [,1]  [,2]   [,3]   [,4]   [,5]   [,6]   [,7]   [,8]   [,9]  [,10]  [,11]  [,12]
 [1,] 54.0  78.8   88.4  244.4  369.6  552.0  657.6  707.2  841.6 1057.6 1486.0 1518.8
 [2,]       108.0  112.8  216.8  280.0  400.4  443.6  431.2  503.6  657.6 1024.0  994.8
 [3,]              132.8  184.8  184.0  240.4  219.6  143.2  151.6  241.6  544.0  450.8
 ...

Optimal Schedule:
  order_period covers_through quantity
1            1              3       84
2            4              4      130
3            5              6      283
4            7              8      140
5            9              9      124
6           10             10      160
7           11             12      279
```

```r
plot(result)
```

This produces a bar chart with blue bars for order quantities and a red line for ending inventory.

## Understanding the Output

### RIC (Relevant Inventory Costs)

The minimum total ordering + holding cost achievable. For the course example, RIC = $501.20 means you can't do better than $501.20 in combined setup and carrying costs.

### Cost Matrix

The cost matrix is N x N where:

| Dimension | Meaning |
|-----------|---------|
| **Row i** | The period in which the order is placed |
| **Column j** | The demand period being satisfied through |
| **Cell [i,j]** | Optimal cost of satisfying demand through period j, given the last order was placed in period i |

Cells where row > column are blank (you can't place an order in a future period to cover past demand).

**Cell-by-cell walkthrough:**

- `[1,1] = 54.00`: Order in period 1 to cover period 1 only. Cost = S = $54 (no holding cost, demand used immediately).
- `[1,3] = 88.40`: Order in period 1 to cover periods 1-3. Cost = $54 (setup) + 62 x $0.40 x 1 (hold period 2 demand for 1 period) + 12 x $0.40 x 2 (hold period 3 demand for 2 periods) = $88.40.
- `[3,3] = 132.80`: Order in period 3 to cover period 3 only, having already optimally covered periods 1-2. Cost = F_2 + S = $78.80 + $54 = $132.80.

### Schedule

The schedule shows when to place each order, what periods it covers, and how many units to order:

- **order_period**: When to place the order
- **covers_through**: The last period this order satisfies
- **quantity**: Total units to order (sum of demand over covered periods)

### Plot

- **Blue bars**: Order quantities, showing the size of each replenishment
- **Red line**: Ending inventory after each period, showing how stock decreases between orders

## How the Algorithm Works

The Wagner-Whitin algorithm finds the cheapest way to satisfy all demand over N periods using a forward dynamic programming approach.

**Forward pass** (building the cost matrix):

For each period j = 1 to N, consider every possible "last order" period i = 1 to j:

```
Cell[i,j] = F(i-1) + S + holding cost of carrying demand from period i through j
```

Where F(i-1) is the minimum cost to cover all demand through period i-1 (with F(0) = 0). After filling column j, set F(j) = min of that column.

**Backward trace** (finding the schedule):

Start at column N. The row with the minimum value is the last order period. Jump left to column (order_period - 1) and repeat. This traces back through the optimal decisions to build the complete ordering schedule.

## Inventory Calculations

### A Note on k (Holding Cost Rate)

All three functions (`SS`, `ROP`, `EOQ`) take `k` and `C` separately instead of a combined H. The parameter `k` is the **monthly (per-period) unit holding cost rate** — the same rate used in `WW()` where H = k x C.

The functions annualize internally: for `SS()` and `ROP()`, the number of periods comes from `length(demand)`; for `EOQ()`, you specify it with the `periods` argument.

```r
k <- 0.02   # monthly holding rate (e.g., 24% annual / 12 months)
C <- 20     # unit cost
# H per month = k * C = 0.40  (what WW uses)
# H per year  = k * C * 12 = 4.80  (annualized internally by SS/ROP/EOQ)
```

### Safety Stock: `SS()`

Computes safety stock to protect against demand variability during lead time.

**Formula:** SS = Z x sigma_d x sqrt(L)

Where:
- Z = `qnorm(service_level)` — the standard normal z-value
- sigma_d = `sd(demand)` — standard deviation of demand per period
- L = lead time (in same time units as demand periods)

```r
demand <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)

# Using alpha (stockout probability)
SS(demand, L = 1, k = 0.02, C = 20, alpha = 0.05)

# Using service level (equivalent)
SS(demand, L = 1, k = 0.02, C = 20, service_level = 0.95)
```

Returns `$SS` (safety stock units) and `$annual_holding_cost` (= SS x k x C x length(demand)).

### Reorder Point: `ROP()`

Computes the inventory level at which to place a new order.

**Formula:** ROP = SS + d_bar x L

Where d_bar = `mean(demand)` is the average demand per period.

```r
ROP(demand, L = 1, k = 0.02, C = 20, alpha = 0.05)
```

Returns `$ROP`, `$SS`, `$annual_holding_cost`, `$d_bar`, and `$sigma_d`.

### Economic Order Quantity: `EOQ()`

The classic EOQ formula for constant demand.

**Formulas:**
- H_annual = k x C x periods
- EOQ = sqrt(2 x R x S / H_annual)
- RIC = EOQ/2 x H_annual + R x S / EOQ

Where R is annual demand and S is ordering cost.

```r
R <- sum(demand)  # 1200 (annual demand)
result <- EOQ(R = R, S = 54, k = 0.02, C = 20, periods = 12)
result$EOQ  # 164.32
result$RIC  # 788.54
```

## Function Reference

| Function | Description |
|----------|-------------|
| `WW(demand, S, H)` | Wagner-Whitin optimal lot sizing |
| `print(result)` | Display RIC, cost matrix, and schedule |
| `plot(result)` | Bar chart of orders with inventory line |
| `SS(demand, L, k, C, alpha, service_level)` | Safety stock calculation |
| `ROP(demand, L, k, C, alpha, service_level)` | Reorder point calculation |
| `EOQ(R, S, k, C, periods)` | Economic order quantity and RIC |

## Sample Code

### Wagner-Whitin: Course Example

```r
library(wagnerwhitin)

S <- 54
H <- 0.02 * 20  # k * C = 0.40
forecast <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)

result <- WW(forecast, S, H)
result$RIC           # 501.2
result$schedule      # 7 orders
plot(result)
```

### Wagner-Whitin: Hillier Textbook Example

```r
result <- WW(c(3, 2, 3, 2), S = 2, H = 0.2)
result$RIC           # 4.8
result$schedule      # Single order covering all 4 periods
```

### Safety Stock and Reorder Point

```r
demand <- c(10, 62, 12, 130, 154, 129, 88, 52, 124, 160, 238, 41)

ss <- SS(demand, L = 1, k = 0.02, C = 20, alpha = 0.05)
ss$SS                # Safety stock in units
ss$annual_holding_cost

rop <- ROP(demand, L = 1, k = 0.02, C = 20, alpha = 0.05)
rop$ROP              # Reorder point
rop$d_bar            # Average demand per period
```

### Economic Order Quantity

```r
R <- sum(demand)     # 1200 (annual demand)
result <- EOQ(R, S = 54, k = 0.02, C = 20, periods = 12)
result$EOQ           # 164.32
result$RIC           # 788.54
```
