;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-event-not-found (err u101))
(define-constant err-betting-closed (err u102))
(define-constant err-invalid-bet-amount (err u103))
(define-constant err-insufficient-balance (err u104))
(define-constant err-event-not-resolved (err u105))
(define-constant err-already-claimed (err u106))
(define-constant err-invalid-outcome (err u107))
(define-constant err-event-already-resolved (err u108))
(define-constant err-invalid-odds (err u109))

;; Configuration
(define-constant min-bet-amount u1000000) ;; 1 STX in micro-STX
(define-constant max-bet-amount u100000000000) ;; 100,000 STX
(define-constant platform-fee-rate u250) ;; 2.5% platform fee
(define-constant min-betting-duration u144) ;; ~1 day in blocks

;; Bet outcomes
(define-constant outcome-team-a u1)
(define-constant outcome-team-b u2)
(define-constant outcome-draw u3)

;; Event status
(define-constant status-open u1)
(define-constant status-closed u2)
(define-constant status-resolved u3)
(define-constant status-cancelled u4)

;; Data Variables
(define-data-var total-events uint u0)
(define-data-var platform-treasury uint u0)
(define-data-var oracle-address principal tx-sender)

;; Data Maps
(define-map sports-events
    uint ;; event-id
    {
        title: (string-ascii 128),
        team-a: (string-ascii 64),
        team-b: (string-ascii 64),
        event-date: uint,
        betting-deadline: uint,
        total-pool: uint,
        team-a-pool: uint,
        team-b-pool: uint,
        draw-pool: uint,
        status: uint,
        final-outcome: (optional uint),
        resolution-time: (optional uint)
    })

(define-map user-bets
    {event-id: uint, user: principal, bet-id: uint}
    {
        amount: uint,
        outcome: uint,
        odds: uint,
        timestamp: uint,
        claimed: bool
    })

(define-map user-bet-count principal uint)
(define-map event-bet-count uint uint)

;; Public Functions

;; Create a new sports event
(define-public (create-event 
    (title (string-ascii 128))
    (team-a (string-ascii 64))
    (team-b (string-ascii 64))
    (event-date uint)
    (betting-duration uint))
    (let (
        (event-id (+ (var-get total-events) u1))
        (betting-deadline (+ block-height betting-duration)))
        
        ;; Validate inputs
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> (len title) u0) err-invalid-outcome)
        (asserts! (> (len team-a) u0) err-invalid-outcome)
        (asserts! (> (len team-b) u0) err-invalid-outcome)
        (asserts! (>= betting-duration min-betting-duration) err-betting-closed)
        (asserts! (> event-date block-height) err-betting-closed)
        
        ;; Create event
        (map-set sports-events event-id {
            title: title,
            team-a: team-a,
            team-b: team-b,
            event-date: event-date,
            betting-deadline: betting-deadline,
            total-pool: u0,
            team-a-pool: u0,
            team-b-pool: u0,
            draw-pool: u0,
            status: status-open,
            final-outcome: none,
            resolution-time: none
        })
        
        (var-set total-events event-id)
        (ok event-id)))

;; Place a bet on an event
(define-public (place-bet (event-id uint) (outcome uint) (amount uint))
    (let (
        (event-info (unwrap! (map-get? sports-events event-id) err-event-not-found))
        (user-bets-count (default-to u0 (map-get? user-bet-count tx-sender)))
        (bet-id (+ user-bets-count u1))
        (platform-fee (/ (* amount platform-fee-rate) u10000))
        (bet-amount (- amount platform-fee)))
        
        ;; Validate bet
        (asserts! (is-eq (get status event-info) status-open) err-betting-closed)
        (asserts! (<= block-height (get betting-deadline event-info)) err-betting-closed)
        (asserts! (>= amount min-bet-amount) err-invalid-bet-amount)
        (asserts! (<= amount max-bet-amount) err-invalid-bet-amount)
        (asserts! (or (is-eq outcome outcome-team-a) 
                     (is-eq outcome outcome-team-b) 
                     (is-eq outcome outcome-draw)) err-invalid-outcome)
        
        ;; Transfer funds
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Calculate current odds
        (let ((current-odds (calculate-odds event-id outcome (+ bet-amount (get total-pool event-info)))))
            
            ;; Record bet
            (map-set user-bets {event-id: event-id, user: tx-sender, bet-id: bet-id} {
                amount: bet-amount,
                outcome: outcome,
                odds: current-odds,
                timestamp: block-height,
                claimed: false
            })
            
            ;; Update pools
            (update-event-pools event-id outcome bet-amount)
            
            ;; Update counters
            (map-set user-bet-count tx-sender bet-id)
            (map-set event-bet-count event-id (+ (default-to u0 (map-get? event-bet-count event-id)) u1))
            
            ;; Add platform fee to treasury
            (var-set platform-treasury (+ (var-get platform-treasury) platform-fee))
            
            (ok {bet-id: bet-id, odds: current-odds, amount: bet-amount}))))

;; Resolve event outcome (oracle only)
(define-public (resolve-event (event-id uint) (final-outcome uint))
    (let (
        (event-info (unwrap! (map-get? sports-events event-id) err-event-not-found)))
        
        ;; Only oracle can resolve
        (asserts! (is-eq tx-sender (var-get oracle-address)) err-owner-only)
        (asserts! (is-eq (get status event-info) status-open) err-event-already-resolved)
        (asserts! (> block-height (get event-date event-info)) err-betting-closed)
        (asserts! (or (is-eq final-outcome outcome-team-a) 
                     (is-eq final-outcome outcome-team-b) 
                     (is-eq final-outcome outcome-draw)) err-invalid-outcome)
        
        ;; Update event status
        (map-set sports-events event-id 
            (merge event-info {
                status: status-resolved,
                final-outcome: (some final-outcome),
                resolution-time: (some block-height)
            }))
        
        (ok final-outcome)))

;; Claim winnings from a bet
(define-public (claim-winnings (event-id uint) (bet-id uint))
    (let (
        (event-info (unwrap! (map-get? sports-events event-id) err-event-not-found))
        (bet-key {event-id: event-id, user: tx-sender, bet-id: bet-id})
        (bet-info (unwrap! (map-get? user-bets bet-key) err-event-not-found))
        (final-outcome (unwrap! (get final-outcome event-info) err-event-not-resolved)))
        
        ;; Validate claim
        (asserts! (is-eq (get status event-info) status-resolved) err-event-not-resolved)
        (asserts! (not (get claimed bet-info)) err-already-claimed)
        (asserts! (is-eq (get outcome bet-info) final-outcome) err-invalid-outcome)
        
        ;; Calculate payout
        (let ((payout (calculate-payout event-info bet-info final-outcome)))
            
            ;; Mark as claimed
            (map-set user-bets bet-key (merge bet-info {claimed: true}))
            
            ;; Transfer winnings
            (try! (as-contract (stx-transfer? payout tx-sender tx-sender)))
            
            (ok payout))))

;; Private Functions

;; Calculate odds based on current pool distribution
(define-private (calculate-odds (event-id uint) (outcome uint) (total-after-bet uint))
    (let (
        (event-info (unwrap-panic (map-get? sports-events event-id)))
        (outcome-pool (if (is-eq outcome outcome-team-a) 
                         (get team-a-pool event-info)
                         (if (is-eq outcome outcome-team-b) 
                             (get team-b-pool event-info) 
                             (get draw-pool event-info)))))
        
        ;; Simple odds calculation: total-pool / outcome-pool
        (if (> outcome-pool u0)
            (/ (* total-after-bet u100) outcome-pool) ;; Return odds * 100 for precision
            u200))) ;; Default 2:1 odds if no bets on outcome

;; Update event pools after a bet
(define-private (update-event-pools (event-id uint) (outcome uint) (amount uint))
    (let (
        (event-info (unwrap-panic (map-get? sports-events event-id)))
        (new-total (+ (get total-pool event-info) amount)))
        
        (if (is-eq outcome outcome-team-a)
            (map-set sports-events event-id 
                (merge event-info {
                    total-pool: new-total,
                    team-a-pool: (+ (get team-a-pool event-info) amount)
                }))
            (if (is-eq outcome outcome-team-b)
                (map-set sports-events event-id 
                    (merge event-info {
                        total-pool: new-total,
                        team-b-pool: (+ (get team-b-pool event-info) amount)
                    }))
                (map-set sports-events event-id 
                    (merge event-info {
                        total-pool: new-total,
                        draw-pool: (+ (get draw-pool event-info) amount)
                    }))))))

;; Calculate payout for winning bet
(define-private (calculate-payout (event-info (tuple (title (string-ascii 128)) (team-a (string-ascii 64)) (team-b (string-ascii 64)) (event-date uint) (betting-deadline uint) (total-pool uint) (team-a-pool uint) (team-b-pool uint) (draw-pool uint) (status uint) (final-outcome (optional uint)) (resolution-time (optional uint)))) (bet-info (tuple (amount uint) (outcome uint) (odds uint) (timestamp uint) (claimed bool))) (final-outcome uint))
    (let (
        (winning-pool (if (is-eq final-outcome outcome-team-a) 
                         (get team-a-pool event-info)
                         (if (is-eq final-outcome outcome-team-b) 
                             (get team-b-pool event-info) 
                             (get draw-pool event-info))))
        (bet-amount (get amount bet-info))
        (total-pool (get total-pool event-info)))
        
        ;; Payout = (bet-amount / winning-pool) * total-pool
        (if (> winning-pool u0)
            (/ (* bet-amount total-pool) winning-pool)
            bet-amount))) ;; Return original bet if no other winners

;; Read-only Functions

;; Get event information
(define-read-only (get-event (event-id uint))
    (map-get? sports-events event-id))

;; Get user bet information
(define-read-only (get-user-bet (event-id uint) (user principal) (bet-id uint))
    (map-get? user-bets {event-id: event-id, user: user, bet-id: bet-id}))

;; Get current odds for an outcome
(define-read-only (get-current-odds (event-id uint) (outcome uint))
    (match (map-get? sports-events event-id)
        event-info (calculate-odds event-id outcome (get total-pool event-info))
        u0))

;; Get platform statistics
(define-read-only (get-platform-stats)
    {
        total-events: (var-get total-events),
        platform-treasury: (var-get platform-treasury),
        oracle-address: (var-get oracle-address),
        platform-fee-rate: platform-fee-rate,
        min-bet-amount: min-bet-amount
    })

;; Admin Functions

;; Set oracle address (owner only)
(define-public (set-oracle (new-oracle principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set oracle-address new-oracle)
        (ok new-oracle)))

;; Cancel event (owner only)
(define-public (cancel-event (event-id uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (let (
            (event-info (unwrap! (map-get? sports-events event-id) err-event-not-found)))
            
            (map-set sports-events event-id 
                (merge event-info {status: status-cancelled}))
            
            (ok event-id))))

;; Withdraw platform fees (owner only)
(define-public (withdraw-fees (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= amount (var-get platform-treasury)) err-insufficient-balance)
        
        (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
        (var-set platform-treasury (- (var-get platform-treasury) amount))
        
        (ok amount)))