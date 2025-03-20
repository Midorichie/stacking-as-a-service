;; stacking-service.clar (Enhanced)
(define-data-var admin principal 'ST000000000000000000002AMW42H)
(define-data-var emergency-shutdown bool false)

;; Data maps to store user details and stacking amounts.
(define-map users {addr: principal} {stacked: uint, rewards: uint, last-stack-height: uint})

;; Authorized contracts that can distribute rewards
(define-map authorized-contracts principal bool)

;; Constants
(define-constant min-stack-amount u1000)
(define-constant max-stack-amount u100000000)
(define-constant reward-lockup-period u144) ;; ~1 day in blocks

;; Error codes
(define-constant err-not-admin (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-emergency-shutdown (err u102))
(define-constant err-already-registered (err u103))
(define-constant err-not-registered (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-lockup-period (err u106))
(define-constant err-invalid-principal (err u107))

;; Admin-only check
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Validate principal addresses
(define-private (is-valid-principal (address principal))
  (and 
    (not (is-eq address 'ST000000000000000000002AMW42H))  ;; Reject default address
    (not (is-eq address tx-sender))                       ;; Optional: Prevent self-reference
  )
)

;; Check if contract is authorized
(define-private (is-authorized-contract (contract principal))
  (default-to false (map-get? authorized-contracts contract))
)

;; Check if emergency shutdown is active
(define-private (check-emergency)
  (if (var-get emergency-shutdown)
    err-emergency-shutdown
    (ok true)
  )
)

;; Register a new user for stacking
(define-public (register-user)
  (begin
    (asserts! (is-ok (check-emergency)) err-emergency-shutdown)
    (if (is-some (map-get? users {addr: tx-sender}))
      err-already-registered
      (begin
        (map-set users {addr: tx-sender} {stacked: u0, rewards: u0, last-stack-height: block-height})
        (ok "User registered")
      )
    )
  )
)

;; Function to allow stacking of BTC (simulated value)
(define-public (stack-btc (amount uint))
  (begin
    (asserts! (is-ok (check-emergency)) err-emergency-shutdown)
    (asserts! (and (>= amount min-stack-amount) (<= amount max-stack-amount)) err-invalid-amount)
    (match (map-get? users {addr: tx-sender})
      user-data
      (let (
        (new-stacked (+ (get stacked user-data) amount))
      )
        (map-set users 
          {addr: tx-sender} 
          {
            stacked: new-stacked, 
            rewards: (get rewards user-data), 
            last-stack-height: block-height
          }
        )
        (ok new-stacked)
      )
      err-not-registered
    )
  )
)

;; Function to distribute rewards based on stacking amounts
(define-public (distribute-rewards (addr principal) (reward uint))
  (begin
    (asserts! (is-ok (check-emergency)) err-emergency-shutdown)
    ;; Check if caller is admin or an authorized contract
    (asserts! (or (is-admin) (is-authorized-contract contract-caller)) err-not-authorized)
    (asserts! (> reward u0) err-invalid-amount)
    (asserts! (is-valid-principal addr) err-invalid-principal)
    
    ;; Validate the user exists
    (match (map-get? users {addr: addr})
      user-data
      (let (
        (new-rewards (+ (get rewards user-data) reward))
      )
        (map-set users 
          {addr: addr} 
          {
            stacked: (get stacked user-data), 
            rewards: new-rewards, 
            last-stack-height: (get last-stack-height user-data)
          }
        )
        (ok new-rewards)
      )
      err-not-registered
    )
  )
)

;; Function to withdraw rewards
(define-public (withdraw-rewards)
  (begin
    (asserts! (is-ok (check-emergency)) err-emergency-shutdown)
    (match (map-get? users {addr: tx-sender})
      user-data
      (let (
        (current-rewards (get rewards user-data))
        (last-stack (get last-stack-height user-data))
      )
        ;; Check the lockup period before allowing withdrawal
        (asserts! (>= (- block-height last-stack) reward-lockup-period) err-lockup-period)
        ;; Reset rewards to 0 after withdrawal
        (map-set users 
          {addr: tx-sender} 
          {
            stacked: (get stacked user-data), 
            rewards: u0, 
            last-stack-height: (get last-stack-height user-data)
          }
        )
        (ok current-rewards)
      )
      err-not-registered
    )
  )
)

;; Update admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) err-not-admin)
    (asserts! (is-valid-principal new-admin) err-invalid-principal)
    (var-set admin new-admin)
    (ok new-admin)
  )
)

;; Add an authorized contract
(define-public (authorize-contract (contract principal))
  (begin
    (asserts! (is-admin) err-not-admin)
    (asserts! (is-valid-principal contract) err-invalid-principal)
    (map-set authorized-contracts contract true)
    (ok contract)
  )
)

;; Remove an authorized contract
(define-public (revoke-contract (contract principal))
  (begin
    (asserts! (is-admin) err-not-admin)
    (asserts! (is-valid-principal contract) err-invalid-principal)
    (map-delete authorized-contracts contract)
    (ok contract)
  )
)

;; Toggle emergency shutdown
(define-public (toggle-emergency-shutdown)
  (begin
    (asserts! (is-admin) err-not-admin)
    (var-set emergency-shutdown (not (var-get emergency-shutdown)))
    (ok (var-get emergency-shutdown))
  )
)

;; Get user info
(define-read-only (get-user-info (addr principal))
  (match (map-get? users {addr: addr})
    user-data (ok user-data)
    err-not-registered
  )
)

;; Check if a contract is authorized
(define-read-only (is-contract-authorized (contract principal))
  (ok (is-authorized-contract contract))
)
