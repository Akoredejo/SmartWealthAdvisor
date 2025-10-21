;; Smart Wealth Growth Advisor
;; A decentralized wealth management system that tracks investments, calculates growth,
;; provides risk-adjusted recommendations, and manages advisory fees.

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-invalid-risk-level (err u105))
(define-constant err-portfolio-exists (err u106))

;; Fee structure (in basis points: 1 bp = 0.01%)
(define-constant advisory-fee-rate u100) ;; 1% annual fee
(define-constant performance-fee-rate u2000) ;; 20% on gains
(define-constant min-investment u1000000) ;; 1 STX minimum

;; Risk levels: 1=Conservative, 2=Moderate, 3=Aggressive
(define-constant risk-conservative u1)
(define-constant risk-moderate u2)
(define-constant risk-aggressive u3)

;; data maps and vars
(define-map portfolios
    principal
    {
        total-invested: uint,
        current-value: uint,
        risk-level: uint,
        last-updated: uint,
        advisory-fees-paid: uint,
        strategy-id: uint,
        active: bool
    }
)

(define-map investment-strategies
    uint
    {
        name: (string-ascii 50),
        min-risk: uint,
        max-risk: uint,
        target-return: uint, ;; in basis points
        recommended-allocation: (list 5 uint) ;; percentage allocations
    }
)

(define-map growth-history
    {user: principal, period: uint}
    {
        value: uint,
        growth-rate: int,
        timestamp: uint
    }
)

(define-data-var total-aum uint u0) ;; Assets Under Management
(define-data-var strategy-counter uint u0)
(define-data-var platform-fees-collected uint u0)

;; private functions

;; Calculate advisory fee based on portfolio value and time elapsed
(define-private (calculate-advisory-fee (portfolio-value uint) (days-elapsed uint))
    (let
        (
            (annual-fee (/ (* portfolio-value advisory-fee-rate) u10000))
            (daily-fee (/ annual-fee u365))
        )
        (* daily-fee days-elapsed)
    )
)

;; Calculate performance fee on realized gains
(define-private (calculate-performance-fee (initial-value uint) (current-value uint))
    (if (> current-value initial-value)
        (let
            (
                (gains (- current-value initial-value))
            )
            (/ (* gains performance-fee-rate) u10000)
        )
        u0
    )
)

;; Validate risk level input
(define-private (is-valid-risk-level (risk uint))
    (and (>= risk risk-conservative) (<= risk risk-aggressive))
)

;; Calculate growth percentage (in basis points)
(define-private (calculate-growth-rate (initial uint) (current uint))
    (if (is-eq initial u0)
        0
        (let
            (
                (difference (if (>= current initial)
                    (to-int (- current initial))
                    (* -1 (to-int (- initial current)))))
            )
            (/ (* difference 10000) (to-int initial))
        )
    )
)

;; Recommend strategy based on risk level
(define-private (get-recommended-strategy (risk-level uint))
    (if (is-eq risk-level risk-conservative)
        u1
        (if (is-eq risk-level risk-moderate)
            u2
            u3
        )
    )
)

;; public functions

;; Initialize investment strategies (owner only)
(define-public (initialize-strategies)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        ;; Conservative strategy
        (map-set investment-strategies u1
            {
                name: "Conservative Growth",
                min-risk: risk-conservative,
                max-risk: risk-conservative,
                target-return: u500, ;; 5% target
                recommended-allocation: (list u60 u30 u10 u0 u0)
            }
        )
        
        ;; Moderate strategy
        (map-set investment-strategies u2
            {
                name: "Balanced Portfolio",
                min-risk: risk-moderate,
                max-risk: risk-moderate,
                target-return: u1200, ;; 12% target
                recommended-allocation: (list u40 u30 u20 u10 u0)
            }
        )
        
        ;; Aggressive strategy
        (map-set investment-strategies u3
            {
                name: "Growth Maximizer",
                min-risk: risk-aggressive,
                max-risk: risk-aggressive,
                target-return: u2500, ;; 25% target
                recommended-allocation: (list u20 u20 u30 u20 u10)
            }
        )
        
        (var-set strategy-counter u3)
        (ok true)
    )
)

;; Create new portfolio
(define-public (create-portfolio (initial-investment uint) (risk-level uint))
    (let
        (
            (existing-portfolio (map-get? portfolios tx-sender))
        )
        (asserts! (is-none existing-portfolio) err-portfolio-exists)
        (asserts! (>= initial-investment min-investment) err-invalid-amount)
        (asserts! (is-valid-risk-level risk-level) err-invalid-risk-level)
        
        (map-set portfolios tx-sender
            {
                total-invested: initial-investment,
                current-value: initial-investment,
                risk-level: risk-level,
                last-updated: block-height,
                advisory-fees-paid: u0,
                strategy-id: (get-recommended-strategy risk-level),
                active: true
            }
        )
        
        (var-set total-aum (+ (var-get total-aum) initial-investment))
        (ok true)
    )
)

;; Update portfolio value (simulates market movements)
(define-public (update-portfolio-value (new-value uint))
    (let
        (
            (portfolio (unwrap! (map-get? portfolios tx-sender) err-not-found))
        )
        (asserts! (get active portfolio) err-unauthorized)
        (asserts! (> new-value u0) err-invalid-amount)
        
        (map-set portfolios tx-sender
            (merge portfolio {
                current-value: new-value,
                last-updated: block-height
            })
        )
        
        (ok true)
    )
)

;; Get portfolio details
(define-read-only (get-portfolio (user principal))
    (ok (map-get? portfolios user))
)

;; Get investment strategy
(define-read-only (get-strategy (strategy-id uint))
    (ok (map-get? investment-strategies strategy-id))
)

;; Calculate current advisory fees owed
(define-read-only (get-fees-owed (user principal))
    (match (map-get? portfolios user)
        portfolio
        (let
            (
                (blocks-elapsed (- block-height (get last-updated portfolio)))
                (days-elapsed (/ blocks-elapsed u144)) ;; Assuming ~144 blocks per day
                (advisory-fee (calculate-advisory-fee (get current-value portfolio) days-elapsed))
                (performance-fee (calculate-performance-fee (get total-invested portfolio) (get current-value portfolio)))
            )
            (ok {advisory-fee: advisory-fee, performance-fee: performance-fee, total: (+ advisory-fee performance-fee)})
        )
        err-not-found
    )
)


