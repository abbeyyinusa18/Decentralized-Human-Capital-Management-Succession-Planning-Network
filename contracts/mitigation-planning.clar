;; Mitigation Planning Contract
;; Plans and tracks risk mitigation strategies

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-NOT-FOUND (err u401))
(define-constant ERR-INVALID-INPUT (err u402))
(define-constant ERR-PLAN-LOCKED (err u403))

;; Data Variables
(define-data-var next-plan-id uint u1)
(define-data-var next-action-id uint u1)

;; Data Maps
(define-map mitigation-plans
  { plan-id: uint }
  {
    risk-id: uint,
    title: (string-ascii 200),
    description: (string-ascii 1000),
    owner: principal,
    status: (string-ascii 20),
    priority: uint,
    estimated-cost: uint,
    actual-cost: uint,
    start-date: uint,
    target-completion: uint,
    actual-completion: (optional uint),
    effectiveness-score: (optional uint),
    created-at: uint,
    updated-at: uint
  }
)

(define-map mitigation-actions
  { plan-id: uint, action-id: uint }
  {
    title: (string-ascii 200),
    description: (string-ascii 500),
    assigned-to: principal,
    status: (string-ascii 20),
    due-date: uint,
    completed-at: (optional uint),
    notes: (string-ascii 500)
  }
)

(define-map plan-approvals
  { plan-id: uint, approver: principal }
  {
    approved: bool,
    notes: (string-ascii 500),
    approved-at: uint
  }
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-plan-owner (plan-id uint))
  (match (map-get? mitigation-plans { plan-id: plan-id })
    plan-data (is-eq tx-sender (get owner plan-data))
    false
  )
)

;; Public Functions

;; Create mitigation plan
(define-public (create-mitigation-plan
  (risk-id uint)
  (title (string-ascii 200))
  (description (string-ascii 1000))
  (priority uint)
  (estimated-cost uint)
  (duration-blocks uint))
  (let
    (
      (plan-id (var-get next-plan-id))
      (current-block-height block-height)
      (target-completion (+ current-block-height duration-blocks))
    )
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (and (<= priority u5) (>= priority u1)) ERR-INVALID-INPUT)
    (asserts! (> duration-blocks u0) ERR-INVALID-INPUT)

    (map-set mitigation-plans
      { plan-id: plan-id }
      {
        risk-id: risk-id,
        title: title,
        description: description,
        owner: tx-sender,
        status: "draft",
        priority: priority,
        estimated-cost: estimated-cost,
        actual-cost: u0,
        start-date: current-block-height,
        target-completion: target-completion,
        actual-completion: none,
        effectiveness-score: none,
        created-at: current-block-height,
        updated-at: current-block-height
      }
    )

    (var-set next-plan-id (+ plan-id u1))
    (ok plan-id)
  )
)

;; Add mitigation action
(define-public (add-mitigation-action
  (plan-id uint)
  (title (string-ascii 200))
  (description (string-ascii 500))
  (assigned-to principal)
  (due-blocks uint))
  (let
    (
      (action-id (var-get next-action-id))
      (current-block-height block-height)
      (due-date (+ current-block-height due-blocks))
    )
    (asserts! (is-plan-owner plan-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? mitigation-plans { plan-id: plan-id })) ERR-NOT-FOUND)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)

    (map-set mitigation-actions
      { plan-id: plan-id, action-id: action-id }
      {
        title: title,
        description: description,
        assigned-to: assigned-to,
        status: "assigned",
        due-date: due-date,
        completed-at: none,
        notes: ""
      }
    )

    (var-set next-action-id (+ action-id u1))
    (ok action-id)
  )
)

;; Update plan status
(define-public (update-plan-status (plan-id uint) (new-status (string-ascii 20)))
  (let
    (
      (plan-data (unwrap! (map-get? mitigation-plans { plan-id: plan-id }) ERR-NOT-FOUND))
      (current-block-height block-height)
    )
    (asserts! (or (is-plan-owner plan-id) (is-contract-owner)) ERR-NOT-AUTHORIZED)

    (map-set mitigation-plans
      { plan-id: plan-id }
      (merge plan-data {
        status: new-status,
        updated-at: current-block-height
      })
    )
    (ok true)
  )
)

;; Complete action
(define-public (complete-action (plan-id uint) (action-id uint) (notes (string-ascii 500)))
  (let
    (
      (action-data (unwrap! (map-get? mitigation-actions { plan-id: plan-id, action-id: action-id }) ERR-NOT-FOUND))
      (current-block-height block-height)
    )
    (asserts! (is-eq tx-sender (get assigned-to action-data)) ERR-NOT-AUTHORIZED)

    (map-set mitigation-actions
      { plan-id: plan-id, action-id: action-id }
      (merge action-data {
        status: "completed",
        completed-at: (some current-block-height),
        notes: notes
      })
    )
    (ok true)
  )
)

;; Update actual cost
(define-public (update-actual-cost (plan-id uint) (actual-cost uint))
  (let
    (
      (plan-data (unwrap! (map-get? mitigation-plans { plan-id: plan-id }) ERR-NOT-FOUND))
      (current-block-height block-height)
    )
    (asserts! (is-plan-owner plan-id) ERR-NOT-AUTHORIZED)

    (map-set mitigation-plans
      { plan-id: plan-id }
      (merge plan-data {
        actual-cost: actual-cost,
        updated-at: current-block-height
      })
    )
    (ok true)
  )
)

;; Approve plan
(define-public (approve-plan (plan-id uint) (notes (string-ascii 500)))
  (let
    (
      (current-block-height block-height)
    )
    (asserts! (is-some (map-get? mitigation-plans { plan-id: plan-id })) ERR-NOT-FOUND)

    (map-set plan-approvals
      { plan-id: plan-id, approver: tx-sender }
      {
        approved: true,
        notes: notes,
        approved-at: current-block-height
      }
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-mitigation-plan (plan-id uint))
  (map-get? mitigation-plans { plan-id: plan-id })
)

(define-read-only (get-mitigation-action (plan-id uint) (action-id uint))
  (map-get? mitigation-actions { plan-id: plan-id, action-id: action-id })
)

(define-read-only (get-plan-approval (plan-id uint) (approver principal))
  (map-get? plan-approvals { plan-id: plan-id, approver: approver })
)
