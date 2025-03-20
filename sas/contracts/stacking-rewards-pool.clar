;; stacking-rewards-pool.clar
;; A contract to manage a pool of rewards for the stacking service

(define-data-var pool-admin principal 'ST000000000000000000002AMW42H)
(define-data-var stacking-contract principal 'ST000000000000000000002AMW42H)

;; Total rewards in the pool
(define-data-var total-rewards uint u0)

;; Tracking contributions to the pool
(define-map contributors principal uint)

;; Events
(define-map reward-distribution-events 
  {event-id: uint} 
  {distributor: principal, amount: uint, timestamp: uint, target: principal}
)
(define-data-var next-event-id uint u0)

;; Constants
(define-constant err-not-admin (err u200))
(define-constant err-invalid-amount (err u201))
(define-constant err-insufficient-funds (err u202))
(define-constant err-list-mismatch (err u203))
(define-constant err-call-failed (err u204))
(define-constant err-invalid-principal (err u205))

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get pool-admin))
)

;; Validate principal addresses
(define-private (is-valid-principal (address principal))
  (and 
    (not (is-eq address 'ST000000000000000000002AMW42H))  ;; Reject default address
    (not (is-eq address tx-sender))                       ;; Optional: Prevent self-reference
  )
)

;; Contribute to the rewards pool
(define-public (contribute-to-pool (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Update total rewards
    (var-set total-rewards (+ (var-get total-rewards) amount))
    
    ;; Track individual contribution
    (map-set contributors 
      tx-sender 
      (+ (default-to u0 (map-get? contributors tx-sender)) amount)
    )
    
    (ok (var-get total-rewards))
  )
)

;; Distribute rewards to a stacker
(define-public (distribute-to-stacker (stacker principal) (amount uint))
  (begin
    (asserts! (is-admin) err-not-admin)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= amount (var-get total-rewards)) err-insufficient-funds)
    (asserts! (is-valid-principal stacker) err-invalid-principal)
    
    ;; Reduce total rewards
    (var-set total-rewards (- (var-get total-rewards) amount))
    
    ;; Record the distribution event
    (let ((event-id (var-get next-event-id)))
      (map-set reward-distribution-events
        {event-id: event-id}
        {
          distributor: tx-sender,
          amount: amount,
          timestamp: block-height,
          target: stacker
        }
      )
      (var-set next-event-id (+ event-id u1))
      
      ;; Call the stacking contract to distribute rewards
      (as-contract (contract-call? .stacking-service distribute-rewards stacker amount))
    )
  )
)

;; Batch distribute rewards based on stacking amounts
(define-public (batch-distribute (stackers (list 10 principal)) (amounts (list 10 uint)))
  (begin
    (asserts! (is-admin) err-not-admin)
    
    ;; Check if lists have same length
    (asserts! (is-eq (len stackers) (len amounts)) err-list-mismatch)
    
    ;; Validate each stacker
    (asserts! (fold and (map is-valid-principal stackers) true) err-invalid-principal)
    
    ;; Calculate total distribution amount
    (let ((total-amount (fold + amounts u0)))
      (asserts! (<= total-amount (var-get total-rewards)) err-insufficient-funds)
      
      ;; Reduce total rewards
      (var-set total-rewards (- (var-get total-rewards) total-amount))
      
      ;; Process each distribution
      (ok (map distribute-single-reward stackers amounts))
    )
  )
)

;; Helper function for batch distribution
(define-private (distribute-single-reward (stacker principal) (amount uint))
  (begin
    ;; Record the distribution event
    (let ((event-id (var-get next-event-id)))
      (map-set reward-distribution-events
        {event-id: event-id}
        {
          distributor: tx-sender,
          amount: amount,
          timestamp: block-height,
          target: stacker
        }
      )
      (var-set next-event-id (+ event-id u1))
      
      ;; Call the stacking contract to distribute rewards without wrapping in match
      (try! (as-contract (contract-call? .stacking-service distribute-rewards stacker amount)))
      (ok amount)
    )
  )
)

;; Update the stacking contract reference
(define-public (set-stacking-contract (new-contract principal))
  (begin
    (asserts! (is-admin) err-not-admin)
    (asserts! (is-valid-principal new-contract) err-invalid-principal)
    (var-set stacking-contract new-contract)
    (ok new-contract)
  )
)

;; Update the pool admin
(define-public (set-pool-admin (new-admin principal))
  (begin
    (asserts! (is-admin) err-not-admin)
    (asserts! (is-valid-principal new-admin) err-invalid-principal)
    (var-set pool-admin new-admin)
    (ok new-admin)
  )
)

;; Get the total rewards in the pool
(define-read-only (get-total-rewards)
  (var-get total-rewards)
)

;; Get a contributor's total contribution
(define-read-only (get-contribution (contributor principal))
  (default-to u0 (map-get? contributors contributor))
)

;; Get a specific reward distribution event
(define-read-only (get-distribution-event (event-id uint))
  (map-get? reward-distribution-events {event-id: event-id})
)
