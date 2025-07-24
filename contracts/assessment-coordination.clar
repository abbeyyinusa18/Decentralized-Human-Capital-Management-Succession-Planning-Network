;; Assessment Coordination Contract
;; Coordinates risk assessments across multiple stakeholders

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-NOT-FOUND (err u301))
(define-constant ERR-INVALID-INPUT (err u302))
(define-constant ERR-INSUFFICIENT-RESOURCES (err u303))
(define-constant ERR-ASSESSMENT-CLOSED (err u304))

;; Data Variables
(define-data-var next-assessment-id uint u1)
(define-data-var total-budget uint u1000000)

;; Data Maps
(define-map assessments
  { assessment-id: uint }
  {
    title: (string-ascii 200),
    description: (string-ascii 1000),
    coordinator: principal,
    status: (string-ascii 20),
    budget-allocated: uint,
    budget-used: uint,
    start-date: uint,
    end-date: uint,
    created-at: uint,
    updated-at: uint
  }
)

(define-map assessment-participants
  { assessment-id: uint, participant: principal }
  {
    role: (string-ascii 50),
    assigned-at: uint,
    status: (string-ascii 20)
  }
)

(define-map assessment-tasks
  { assessment-id: uint, task-id: uint }
  {
    title: (string-ascii 200),
    description: (string-ascii 500),
    assigned-to: principal,
    status: (string-ascii 20),
    due-date: uint,
    completed-at: (optional uint)
  }
)

(define-data-var next-task-id uint u1)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-assessment-coordinator (assessment-id uint))
  (match (map-get? assessments { assessment-id: assessment-id })
    assessment-data (is-eq tx-sender (get coordinator assessment-data))
    false
  )
)

;; Public Functions

;; Create new assessment
(define-public (create-assessment
  (title (string-ascii 200))
  (description (string-ascii 1000))
  (budget-requested uint)
  (duration-blocks uint))
  (let
    (
      (assessment-id (var-get next-assessment-id))
      (current-block-height block-height)
      (end-date (+ current-block-height duration-blocks))
    )
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    ;; Fixed: Proper budget validation without HTML elements
    (asserts! (<= budget-requested (var-get total-budget)) ERR-INSUFFICIENT-RESOURCES)
    (asserts! (> duration-blocks u0) ERR-INVALID-INPUT)

    (map-set assessments
      { assessment-id: assessment-id }
      {
        title: title,
        description: description,
        coordinator: tx-sender,
        status: "planning",
        budget-allocated: budget-requested,
        budget-used: u0,
        start-date: current-block-height,
        end-date: end-date,
        created-at: current-block-height,
        updated-at: current-block-height
      }
    )

    (var-set next-assessment-id (+ assessment-id u1))
    (ok assessment-id)
  )
)

;; Add participant to assessment
(define-public (add-participant
  (assessment-id uint)
  (participant principal)
  (role (string-ascii 50)))
  (let
    (
      (current-block-height block-height)
    )
    (asserts! (is-assessment-coordinator assessment-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? assessments { assessment-id: assessment-id })) ERR-NOT-FOUND)
    (asserts! (> (len role) u0) ERR-INVALID-INPUT)

    (map-set assessment-participants
      { assessment-id: assessment-id, participant: participant }
      {
        role: role,
        assigned-at: current-block-height,
        status: "active"
      }
    )
    (ok true)
  )
)

;; Create assessment task
(define-public (create-task
  (assessment-id uint)
  (title (string-ascii 200))
  (description (string-ascii 500))
  (assigned-to principal)
  (due-blocks uint))
  (let
    (
      (task-id (var-get next-task-id))
      (current-block-height block-height)
      (due-date (+ current-block-height due-blocks))
    )
    (asserts! (is-assessment-coordinator assessment-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? assessments { assessment-id: assessment-id })) ERR-NOT-FOUND)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)

    (map-set assessment-tasks
      { assessment-id: assessment-id, task-id: task-id }
      {
        title: title,
        description: description,
        assigned-to: assigned-to,
        status: "assigned",
        due-date: due-date,
        completed-at: none
      }
    )

    (var-set next-task-id (+ task-id u1))
    (ok task-id)
  )
)

;; Update assessment status
(define-public (update-assessment-status (assessment-id uint) (new-status (string-ascii 20)))
  (let
    (
      (assessment-data (unwrap! (map-get? assessments { assessment-id: assessment-id }) ERR-NOT-FOUND))
      (current-block-height block-height)
    )
    (asserts! (is-assessment-coordinator assessment-id) ERR-NOT-AUTHORIZED)

    (map-set assessments
      { assessment-id: assessment-id }
      (merge assessment-data {
        status: new-status,
        updated-at: current-block-height
      })
    )
    (ok true)
  )
)

;; Complete task
(define-public (complete-task (assessment-id uint) (task-id uint))
  (let
    (
      (task-data (unwrap! (map-get? assessment-tasks { assessment-id: assessment-id, task-id: task-id }) ERR-NOT-FOUND))
      (current-block-height block-height)
    )
    (asserts! (is-eq tx-sender (get assigned-to task-data)) ERR-NOT-AUTHORIZED)

    (map-set assessment-tasks
      { assessment-id: assessment-id, task-id: task-id }
      (merge task-data {
        status: "completed",
        completed-at: (some current-block-height)
      })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-assessment (assessment-id uint))
  (map-get? assessments { assessment-id: assessment-id })
)

(define-read-only (get-participant (assessment-id uint) (participant principal))
  (map-get? assessment-participants { assessment-id: assessment-id, participant: participant })
)

(define-read-only (get-task (assessment-id uint) (task-id uint))
  (map-get? assessment-tasks { assessment-id: assessment-id, task-id: task-id })
)

(define-read-only (get-total-budget)
  (var-get total-budget)
)
