SmartWealthAdvisor
==================

A detailed README for the Stacks Clarity smart contract, **SmartWealthAdvisor**, a decentralized wealth management system.

* * * * *

💡 Overview
-----------

The `SmartWealthAdvisor` contract provides a decentralized platform for wealth management, allowing users to create investment portfolios, track their growth, and receive risk-adjusted investment recommendations. It incorporates a sophisticated fee structure, including both annual advisory fees and performance fees on realized gains, all managed transparently on the Stacks blockchain. The system utilizes predefined investment strategies linked to user-selected risk levels (Conservative, Moderate, Aggressive) to provide actionable guidance and comprehensive performance reports.

* * * * *

🛠️ Contract Details
--------------------

This contract is written in **Clarity**, the smart contract language for the Stacks blockchain.

### Data Structures

| **Map/Variable** | **Key** | **Value/Type** | **Description** |
| --- | --- | --- | --- |
| `portfolios` | `principal` (user address) | `{total-invested: uint, current-value: uint, risk-level: uint, last-updated: uint, advisory-fees-paid: uint, strategy-id: uint, active: bool}` | Stores all vital user portfolio data. |
| `investment-strategies` | `uint` (Strategy ID) | `{name: (string-ascii 50), min-risk: uint, max-risk: uint, target-return: uint, recommended-allocation: (list 5 uint)}` | Stores details for predefined investment strategies. |
| `growth-history` | `{user: principal, period: uint}` (User & Block Height) | `{value: uint, growth-rate: int, timestamp: uint}` | Logs the portfolio value and growth rate at the time of report generation. |
| `total-aum` | `uint` | Tracks the **Assets Under Management** (total value of all active portfolios). |  |
| `strategy-counter` | `uint` | A simple counter for new investment strategies (currently initialized to `u3`). |  |
| `platform-fees-collected` | `uint` | Accumulates total fees collected by the platform. |  |

### Constants & Configuration

The contract is configured with key financial and system constants:

| **Constant** | **Value** | **Description** |
| --- | --- | --- |
| `advisory-fee-rate` | `u100` (100 basis points) | **1.00%** annual advisory fee. |
| `performance-fee-rate` | `u2000` (2,000 basis points) | **20.00%** fee on portfolio gains. |
| `min-investment` | `u1000000` | Minimum required initial investment (1 STX, assuming 1 STX = 1,000,000 micro-STX). |
| `risk-conservative` | `u1` | Risk level identifier for Conservative strategy. |
| `risk-moderate` | `u2` | Risk level identifier for Moderate strategy. |
| `risk-aggressive` | `u3` | Risk level identifier for Aggressive strategy. |

### Public Functions (Entrypoints)

| **Function** | **Access** | **Description** |
| --- | --- | --- |
| `initialize-strategies` | Owner-only | Sets up the initial **Conservative (u1)**, **Moderate (u2)**, and **Aggressive (u3)** strategies with their respective target returns and recommended asset allocations. |
| `create-portfolio` | Public | Allows a user to establish a new portfolio with an `initial-investment` (must be $\ge u1000000$) and a `risk-level` (1, 2, or 3). Assigns a recommended strategy and updates `total-aum`. |
| `update-portfolio-value` | Public | Simulates market movement by allowing a user to update their `current-value`. *Note: In a real-world scenario, this would likely be an Oracle-fed or governance-controlled function.* |
| `generate-wealth-growth-report` | Public | Produces a detailed report for a user, calculating absolute gain, growth rate, performance-vs-target, and a **Sharpe Ratio** (risk-adjusted return approximation). It also issues a simple recommendation and logs the performance to `growth-history`. |

### Read-Only Functions

| **Function** | **Description** |
| --- | --- |
| `get-portfolio` | Retrieves the portfolio data for a given `principal`. |
| `get-strategy` | Retrieves the details of a specific investment strategy by its ID. |
| `get-fees-owed` | Calculates the current advisory and performance fees owed by a user based on time elapsed since last update and current gains. |

### Private Functions (Core Logic)

| **Function** | **Description** |
| --- | --- |
| `calculate-advisory-fee` | Computes the daily pro-rata advisory fee based on `portfolio-value`, using the annual `advisory-fee-rate` (1% per year) and `days-elapsed`. (Assumes 144 blocks $\approx$ 1 day). |
| `calculate-performance-fee` | Calculates the performance fee (20%) on any positive difference between `current-value` and `initial-value`. |
| `is-valid-risk-level` | Utility to validate that the provided risk level is between 1 and 3. |
| `calculate-growth-rate` | Computes the percentage growth/loss from `initial` to `current` value, expressed as a signed integer in **basis points (bps)**. |
| `get-recommended-strategy` | Maps the user's selected risk level (`u1`, `u2`, or `u3`) to the corresponding default `strategy-id`. |

* * * * *

📈 Financial and Analytical Logic
---------------------------------

### Fee Calculation

The contract charges two types of fees:

1.  Advisory Fee: An annual fee of 1.00% of the portfolio's current-value, calculated pro-rata based on the time elapsed (in days) since the portfolio was last updated (last-updated).

    $$\text{Annual Fee} = \frac{\text{Portfolio Value} \times \text{Advisory Fee Rate}}{10000}$$

    $$\text{Daily Fee} = \frac{\text{Annual Fee}}{365}$$

    $$\text{Fee Owed} = \text{Daily Fee} \times \text{Days Elapsed}$$

2.  Performance Fee: A fee of 20.00% on realized gains. This is only charged on the total positive gain (i.e., current-value > total-invested).

    $$\text{Performance Fee} = \frac{(\text{Current Value} - \text{Total Invested}) \times \text{Performance Fee Rate}}{10000}$$

### Performance Metrics

The `generate-wealth-growth-report` function provides advanced metrics for a comprehensive review:

-   Growth Rate (in bps): Measures the total percentage change in portfolio value.

    $$\text{Growth Rate (bps)} = \frac{(\text{Current} - \text{Initial}) \times 10000}{\text{Initial}}$$

-   **Performance vs. Target (Gap):** Compares the actual `growth-rate` against the strategy's predefined `target-return` in basis points.

-   **Sharpe Ratio (Approximation):** A basic risk-adjusted return metric is calculated, which serves as a rough proxy for comparing returns relative to the portfolio's specified risk level.

    -   For risk levels $\gt u1$: $\text{Sharpe Ratio} \approx \frac{\text{Growth Rate (bps)}}{\text{Risk Level} \times 100}$

    -   For risk level $u1$: $\text{Sharpe Ratio} = \text{Growth Rate (bps)}$ (simplification)

### Recommendation Logic

The automated investment recommendation is based on how the portfolio is performing relative to its target return:

| **Condition** | **Performance Gap** | **Recommendation** | **Action Implied** |
| --- | --- | --- | --- |
| **Underperforming** | `< -500` (underperforming target by $>5.0\%$) | `"REBALANCE-INCREASE-RISK"` | Suggests seeking higher returns, potentially by adjusting the risk level. |
| **Overperforming** | `> 1000` (overperforming target by $>10.0\%$) | `"SECURE-PROFITS"` | Suggests taking some capital off the table to lock in gains. |
| **On Track** | All other cases | `"MAINTAIN-STRATEGY"` | Continue with the current investment plan. |

* * * * *

🚀 Usage Guide
--------------

### Setup

1.  **Deploy the Contract**: Deploy the Clarity code to the Stacks blockchain.

2.  **Initialize Strategies**: The contract owner must call `(initialize-strategies)` once to populate the `investment-strategies` map with the predefined risk profiles.

### User Flow

1.  **Create Portfolio**: Call `(create-portfolio u2000000 u2)` (Example: $2$ STX investment, Moderate risk).

2.  **Monitor/Update**: As market conditions change, the user or an automated process calls `(update-portfolio-value u2200000)` to reflect the new market value.

3.  **Generate Report**: The user calls `(generate-wealth-growth-report tx-sender)` to get their performance analysis, risk-adjusted metrics, and investment recommendation. This also logs the current performance snapshot.

4.  **Check Fees**: The user can check their fee obligations with `(get-fees-owed tx-sender)`. *Note: A separate function for fee collection and transfer would be implemented in a complete system.*

* * * * *

🔒 Error Codes
--------------

| **Code** | **Constant** | **Description** |
| --- | --- | --- |
| `u100` | `err-owner-only` | The transaction sender is not the contract owner. |
| `u101` | `err-not-found` | Portfolio or strategy ID does not exist. |
| `u102` | `err-insufficient-balance` | Not used in current version, but reserved. |
| `u103` | `err-invalid-amount` | Initial investment is below `min-investment` or `new-value` is zero. |
| `u104` | `err-unauthorized` | Portfolio is inactive. |
| `u105` | `err-invalid-risk-level` | Risk level provided is not 1, 2, or 3. |
| `u106` | `err-portfolio-exists` | An attempt was made to create a portfolio for an address that already has one. |

* * * * *

🤝 Contribution
---------------

We welcome contributions to enhance the `SmartWealthAdvisor` contract. Before making significant changes, please open an issue to discuss what you would like to change.

### Guidelines:

1.  **Clarity Best Practices**: All code must adhere to Clarity language best practices, focusing on safety and predictability.

2.  **Gas Efficiency**: Optimize functions for low transaction costs.

3.  **Testing**: Comprehensive unit tests covering all public functions and edge cases (especially fee calculation and error handling) are required for any pull request.

4.  **Feature Scope**: Proposed features should align with the core mission: decentralized, risk-adjusted wealth tracking and advice.

### Suggested Enhancements:

-   Implementation of token transfers for initial investment, fee collection, and withdrawal.

-   More granular risk-adjusted metrics (e.g., proper Sharpe Ratio with a risk-free rate, Sortino Ratio).

-   Adding a governance mechanism for updating strategies or fee rates.

* * * * *

⚖️ License
----------

This project is licensed under the **MIT License**.

```
MIT License

Copyright (c) 2025 SmartWealthAdvisor

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```
