;; Decentralized Mentorship Network Smart Contract
;; Version: 1.0.0
;; Description: Connect mentors and mentees with tokenized incentives

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-session-exists (err u104))
(define-constant err-session-complete (err u105))
(define-constant err-insufficient-funds (err u106))
(define-constant err-invalid-rating (err u107))

;; Data Variables
(define-data-var platform-fee uint u50) ;; 5% in basis points (50/1000)
(define-data-var min-stake-amount uint u1000000) ;; 1 STX in microSTX
(define-data-var session-counter uint u0)

;; Data Maps
(define-map mentors
  { mentor: principal }
  {
    expertise: (string-utf8 100),
    hourly-rate: uint,
    rating: uint,
    total-sessions: uint,
    is-active: bool,
    stake-amount: uint
  }
)

(define-map mentees
  { mentee: principal }
  {
    total-sessions: uint,
    total-spent: uint
  }
)

(define-map mentorship-sessions
  { session-id: uint }
  {
    mentor: principal,
    mentee: principal,
    duration-hours: uint,
    hourly-rate: uint,
    total-amount: uint,
    status: (string-ascii 20),
    created-at: uint,
    completed-at: (optional uint),
    mentor-rating: (optional uint),
    mentee-rating: (optional uint)
  }
)

(define-map mentor-earnings
  { mentor: principal }
  { total-earned: uint, available-balance: uint }
)

(define-map platform-treasury
  { key: (string-ascii 20) }
  { balance: uint }
)

;; Initialize platform treasury
(map-set platform-treasury { key: "total-fees" } { balance: u0 })

;; Public Functions

;; Register as a mentor
(define-public (register-mentor (expertise (string-utf8 100)) (hourly-rate uint))
  (let
    ((stake (var-get min-stake-amount)))
    (asserts! (> hourly-rate u0) err-invalid-amount)
    (asserts! (>= (stx-get-balance tx-sender) stake) err-insufficient-funds)
    (try! (stx-transfer? stake tx-sender (as-contract tx-sender)))
    (map-set mentors
      { mentor: tx-sender }
      {
        expertise: expertise,
        hourly-rate: hourly-rate,
        rating: u0,
        total-sessions: u0,
        is-active: true,
        stake-amount: stake
      }
    )
    (ok true)
  )
)

;; Update mentor profile
(define-public (update-mentor-profile (expertise (string-utf8 100)) (hourly-rate uint))
  (let
    ((mentor-data (unwrap! (map-get? mentors { mentor: tx-sender }) err-not-found)))
    (asserts! (> hourly-rate u0) err-invalid-amount)
    (map-set mentors
      { mentor: tx-sender }
      (merge mentor-data { expertise: expertise, hourly-rate: hourly-rate })
    )
    (ok true)
  )
)

;; Register as a mentee
(define-public (register-mentee)
  (begin
    (map-set mentees
      { mentee: tx-sender }
      { total-sessions: u0, total-spent: u0 }
    )
    (ok true)
  )
)

;; Book a mentorship session
(define-public (book-session (mentor principal) (duration-hours uint))
  (let
    (
      (mentor-data (unwrap! (map-get? mentors { mentor: mentor }) err-not-found))
      (session-id (+ (var-get session-counter) u1))
      (hourly-rate (get hourly-rate mentor-data))
      (total-amount (* hourly-rate duration-hours))
      (platform-fee-amount (/ (* total-amount (var-get platform-fee)) u1000))
      (mentor-amount (- total-amount platform-fee-amount))
    )
    (asserts! (get is-active mentor-data) err-unauthorized)
    (asserts! (> duration-hours u0) err-invalid-amount)
    (asserts! (>= (stx-get-balance tx-sender) total-amount) err-insufficient-funds)
    
    ;; Transfer payment to contract
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    
    ;; Create session
    (map-set mentorship-sessions
      { session-id: session-id }
      {
        mentor: mentor,
        mentee: tx-sender,
        duration-hours: duration-hours,
        hourly-rate: hourly-rate,
        total-amount: total-amount,
        status: "booked",
        created-at: block-height,
        completed-at: none,
        mentor-rating: none,
        mentee-rating: none
      }
    )
    
    ;; Update session counter
    (var-set session-counter session-id)
    
    ;; Update mentee data
    (match (map-get? mentees { mentee: tx-sender })
      mentee-data (map-set mentees
        { mentee: tx-sender }
        {
          total-sessions: (+ (get total-sessions mentee-data) u1),
          total-spent: (+ (get total-spent mentee-data) total-amount)
        }
      )
      (map-set mentees
        { mentee: tx-sender }
        { total-sessions: u1, total-spent: total-amount }
      )
    )
    
    (ok session-id)
  )
)

;; Complete a mentorship session (called by mentor)
(define-public (complete-session (session-id uint))
  (let
    (
      (session (unwrap! (map-get? mentorship-sessions { session-id: session-id }) err-not-found))
      (mentor (get mentor session))
      (total-amount (get total-amount session))
      (platform-fee-amount (/ (* total-amount (var-get platform-fee)) u1000))
      (mentor-amount (- total-amount platform-fee-amount))
    )
    (asserts! (is-eq tx-sender mentor) err-unauthorized)
    (asserts! (is-eq (get status session) "booked") err-session-complete)
    
    ;; Update session status
    (map-set mentorship-sessions
      { session-id: session-id }
      (merge session {
        status: "completed",
        completed-at: (some block-height)
      })
    )
    
    ;; Update mentor earnings
    (match (map-get? mentor-earnings { mentor: mentor })
      earnings (map-set mentor-earnings
        { mentor: mentor }
        {
          total-earned: (+ (get total-earned earnings) mentor-amount),
          available-balance: (+ (get available-balance earnings) mentor-amount)
        }
      )
      (map-set mentor-earnings
        { mentor: mentor }
        { total-earned: mentor-amount, available-balance: mentor-amount }
      )
    )
    
    ;; Update mentor session count
    (let ((mentor-data (unwrap! (map-get? mentors { mentor: mentor }) err-not-found)))
      (map-set mentors
        { mentor: mentor }
        (merge mentor-data { total-sessions: (+ (get total-sessions mentor-data) u1) })
      )
    )
    
    ;; Add to platform treasury
    (let ((treasury (unwrap! (map-get? platform-treasury { key: "total-fees" }) err-not-found)))
      (map-set platform-treasury
        { key: "total-fees" }
        { balance: (+ (get balance treasury) platform-fee-amount) }
      )
    )
    
    (ok true)
  )
)

;; Rate mentor (called by mentee)
(define-public (rate-mentor (session-id uint) (rating uint))
  (let
    ((session (unwrap! (map-get? mentorship-sessions { session-id: session-id }) err-not-found)))
    (asserts! (is-eq tx-sender (get mentee session)) err-unauthorized)
    (asserts! (is-eq (get status session) "completed") err-unauthorized)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
    
    ;; Update session with mentor rating
    (map-set mentorship-sessions
      { session-id: session-id }
      (merge session { mentor-rating: (some rating) })
    )
    
    ;; Update mentor's average rating
    (let
      (
        (mentor (get mentor session))
        (mentor-data (unwrap! (map-get? mentors { mentor: mentor }) err-not-found))
        (current-rating (get rating mentor-data))
        (total-sessions (get total-sessions mentor-data))
        (new-rating (if (is-eq current-rating u0)
          rating
          (/ (+ (* current-rating (- total-sessions u1)) rating) total-sessions)
        ))
      )
      (map-set mentors
        { mentor: mentor }
        (merge mentor-data { rating: new-rating })
      )
    )
    
    (ok true)
  )
)

;; Rate mentee (called by mentor)
(define-public (rate-mentee (session-id uint) (rating uint))
  (let
    ((session (unwrap! (map-get? mentorship-sessions { session-id: session-id }) err-not-found)))
    (asserts! (is-eq tx-sender (get mentor session)) err-unauthorized)
    (asserts! (is-eq (get status session) "completed") err-unauthorized)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
    
    (map-set mentorship-sessions
      { session-id: session-id }
      (merge session { mentee-rating: (some rating) })
    )
    
    (ok true)
  )
)

;; Withdraw earnings (mentor only)
(define-public (withdraw-earnings (amount uint))
  (let
    ((earnings (unwrap! (map-get? mentor-earnings { mentor: tx-sender }) err-not-found)))
    (asserts! (<= amount (get available-balance earnings)) err-insufficient-funds)
    (asserts! (> amount u0) err-invalid-amount)
    
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    
    (map-set mentor-earnings
      { mentor: tx-sender }
      (merge earnings { available-balance: (- (get available-balance earnings) amount) })
    )
    
    (ok true)
  )
)

;; Deactivate mentor account
(define-public (deactivate-mentor)
  (let
    ((mentor-data (unwrap! (map-get? mentors { mentor: tx-sender }) err-not-found)))
    (map-set mentors
      { mentor: tx-sender }
      (merge mentor-data { is-active: false })
    )
    (ok true)
  )
)

;; Admin Functions

;; Update platform fee (owner only)
(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u200) err-invalid-amount) ;; Max 20%
    (var-set platform-fee new-fee)
    (ok true)
  )
)

;; Update minimum stake amount (owner only)
(define-public (update-min-stake (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-stake-amount new-amount)
    (ok true)
  )
)

;; Withdraw platform fees (owner only)
(define-public (withdraw-platform-fees (amount uint))
  (let
    ((treasury (unwrap! (map-get? platform-treasury { key: "total-fees" }) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount (get balance treasury)) err-insufficient-funds)
    
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    
    (map-set platform-treasury
      { key: "total-fees" }
      { balance: (- (get balance treasury) amount) }
    )
    
    (ok true)
  )
)

;; Read-Only Functions

;; Get mentor info
(define-read-only (get-mentor (mentor principal))
  (map-get? mentors { mentor: mentor })
)

;; Get mentee info
(define-read-only (get-mentee (mentee principal))
  (map-get? mentees { mentee: mentee })
)

;; Get session info
(define-read-only (get-session (session-id uint))
  (map-get? mentorship-sessions { session-id: session-id })
)

;; Get mentor earnings
(define-read-only (get-mentor-earnings (mentor principal))
  (map-get? mentor-earnings { mentor: mentor })
)

;; Get platform stats
(define-read-only (get-platform-stats)
  {
    platform-fee: (var-get platform-fee),
    min-stake-amount: (var-get min-stake-amount),
    total-sessions: (var-get session-counter),
    treasury-balance: (default-to u0 (get balance (map-get? platform-treasury { key: "total-fees" })))
  }
)