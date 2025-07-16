;; Compliance Checking Contract
;; Validates regulatory compliance requirements

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-RULE-NOT-FOUND (err u301))
(define-constant ERR-INVALID-INPUT (err u302))
(define-constant ERR-COMPLIANCE-FAILED (err u303))
(define-constant ERR-INVALID-THRESHOLD (err u304))

;; Data Variables
(define-data-var next-rule-id uint u1)
(define-data-var next-check-id uint u1)

;; Data Maps
(define-map compliance-rules
  { rule-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 200),
    threshold-value: uint,
    operator: (string-ascii 10),
    active: bool,
    created-by: principal,
    created-at: uint
  }
)

(define-map compliance-checks
  { check-id: uint }
  {
    reporter-id: uint,
    rule-id: uint,
    check-value: uint,
    result: bool,
    checked-at: uint,
    checked-by: principal
  }
)

(define-map rule-by-name
  { name: (string-ascii 100) }
  { rule-id: uint }
)

;; Public Functions

;; Create a new compliance rule
(define-public (create-rule (name (string-ascii 100)) (description (string-ascii 200)) (threshold-value uint) (operator (string-ascii 10)))
  (let
    (
      (rule-id (var-get next-rule-id))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> threshold-value u0) ERR-INVALID-THRESHOLD)

    (map-set compliance-rules
      { rule-id: rule-id }
      {
        name: name,
        description: description,
        threshold-value: threshold-value,
        operator: operator,
        active: true,
        created-by: tx-sender,
        created-at: block-height
      }
    )

    (map-set rule-by-name
      { name: name }
      { rule-id: rule-id }
    )

    (var-set next-rule-id (+ rule-id u1))
    (ok rule-id)
  )
)

;; Perform compliance check
(define-public (check-compliance (reporter-id uint) (rule-id uint) (check-value uint))
  (let
    (
      (check-id (var-get next-check-id))
      (rule (unwrap! (map-get? compliance-rules { rule-id: rule-id }) ERR-RULE-NOT-FOUND))
      (result (evaluate-compliance rule check-value))
    )
    (asserts! (get active rule) ERR-RULE-NOT-FOUND)
    (asserts! (> reporter-id u0) ERR-INVALID-INPUT)

    (map-set compliance-checks
      { check-id: check-id }
      {
        reporter-id: reporter-id,
        rule-id: rule-id,
        check-value: check-value,
        result: result,
        checked-at: block-height,
        checked-by: tx-sender
      }
    )

    (var-set next-check-id (+ check-id u1))
    (ok { check-id: check-id, result: result })
  )
)

;; Update rule status
(define-public (update-rule-status (rule-id uint) (active bool))
  (let
    (
      (rule (unwrap! (map-get? compliance-rules { rule-id: rule-id }) ERR-RULE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set compliance-rules
      { rule-id: rule-id }
      (merge rule { active: active })
    )
    (ok true)
  )
)

;; Batch compliance check
(define-public (batch-check-compliance (reporter-id uint) (checks (list 10 { rule-id: uint, check-value: uint })))
  (let
    (
      (results (map check-single-compliance checks))
    )
    (asserts! (> reporter-id u0) ERR-INVALID-INPUT)
    (ok results)
  )
)

;; Read-only Functions

;; Get compliance rule
(define-read-only (get-rule (rule-id uint))
  (map-get? compliance-rules { rule-id: rule-id })
)

;; Get rule by name
(define-read-only (get-rule-by-name (name (string-ascii 100)))
  (match (map-get? rule-by-name { name: name })
    rule-ref (map-get? compliance-rules { rule-id: (get rule-id rule-ref) })
    none
  )
)

;; Get compliance check
(define-read-only (get-check (check-id uint))
  (map-get? compliance-checks { check-id: check-id })
)

;; Validate compliance value
(define-read-only (validate-compliance (rule-id uint) (check-value uint))
  (match (map-get? compliance-rules { rule-id: rule-id })
    rule (evaluate-compliance rule check-value)
    false
  )
)

;; Get next rule ID
(define-read-only (get-next-rule-id)
  (var-get next-rule-id)
)

;; Get next check ID
(define-read-only (get-next-check-id)
  (var-get next-check-id)
)

;; Private Functions

;; Evaluate compliance based on rule
(define-private (evaluate-compliance (rule { name: (string-ascii 100), description: (string-ascii 200), threshold-value: uint, operator: (string-ascii 10), active: bool, created-by: principal, created-at: uint }) (check-value uint))
  (let
    (
      (threshold (get threshold-value rule))
      (op (get operator rule))
    )
    (if (is-eq op "gt")
      (> check-value threshold)
      (if (is-eq op "lt")
        (< check-value threshold)
        (if (is-eq op "gte")
          (>= check-value threshold)
          (if (is-eq op "lte")
            (<= check-value threshold)
            (is-eq check-value threshold)
          )
        )
      )
    )
  )
)

;; Helper for batch checking
(define-private (check-single-compliance (check { rule-id: uint, check-value: uint }))
  (let
    (
      (rule-id (get rule-id check))
      (check-value (get check-value check))
      (rule (unwrap-panic (map-get? compliance-rules { rule-id: rule-id })))
    )
    {
      rule-id: rule-id,
      result: (evaluate-compliance rule check-value)
    }
  )
)
