;; stacking-service.clar
(define-data-var admin principal 'ST000000000000000000002AMW42H)

;; Data maps to store user details and stacking amounts.
(define-map users {addr: principal} {stacked: uint, rewards: uint})

;; Register a new user for stacking
(define-public (register-user)
  (let ((caller tx-sender))
    (if (is-some (map-get? users {addr: caller}))
      (err "User already registered")
      (begin
        (map-set users {addr: caller} {stacked: u0, rewards: u0})
        (ok "User registered")
      )
    )
  )
)

;; Function to allow stacking of BTC (simulated value)
(define-public (stack-btc (amount uint))
  (let ((caller tx-sender))
    (if (is-eq amount u0)
      (err "Amount must be greater than zero")
      (begin
        (match (map-get? users {addr: caller})
          user-data
          (let (
            (new-stacked (+ (get stacked user-data) amount))
          )
            (map-set users {addr: caller} {stacked: new-stacked, rewards: (get rewards user-data)})
            (ok new-stacked)
          )
          (err "User not registered")
        )
      )
    )
  )
)

;; Function to distribute rewards based on stacking amounts
;; Only admin can call this function
(define-public (distribute-rewards (addr principal) (reward uint))
  (let ((caller tx-sender))
    (if (not (is-eq caller (var-get admin)))
      (err "Only admin can distribute rewards")
      (if (is-eq reward u0)
        (err "Reward must be greater than zero")
        (begin
          (match (map-get? users {addr: addr})
            user-data
            (let (
              (new-rewards (+ (get rewards user-data) reward))
            )
              (map-set users {addr: addr} {stacked: (get stacked user-data), rewards: new-rewards})
              (ok new-rewards)
            )
            (err "User not registered")
          )
        )
      )
    )
  )
)

;; Function to withdraw rewards
(define-public (withdraw-rewards)
  (let ((caller tx-sender))
    (match (map-get? users {addr: caller})
      user-data
      (let (
        (current-rewards (get rewards user-data))
      )
        ;; Reset rewards to 0 after withdrawal
        (map-set users {addr: caller} {stacked: (get stacked user-data), rewards: u0})
        (ok current-rewards)
      )
      (err "User not registered")
    )
  )
)
