;; Report Generation Contract
;; Handles creation and management of regulatory reports

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-REPORT-NOT-FOUND (err u201))
(define-constant ERR-INVALID-TEMPLATE (err u202))
(define-constant ERR-INVALID-INPUT (err u203))
(define-constant ERR-REPORTER-NOT-VERIFIED (err u204))

;; Data Variables
(define-data-var next-report-id uint u1)
(define-data-var next-template-id uint u1)

;; Data Maps
(define-map reports
  { report-id: uint }
  {
    reporter-id: uint,
    template-id: uint,
    report-type: (string-ascii 50),
    data-hash: (buff 32),
    created-at: uint,
    status: uint,
    submitted-at: (optional uint)
  }
)

(define-map report-templates
  { template-id: uint }
  {
    name: (string-ascii 100),
    version: (string-ascii 20),
    fields-hash: (buff 32),
    created-by: principal,
    active: bool
  }
)

(define-map template-by-name
  { name: (string-ascii 100) }
  { template-id: uint }
)

;; Public Functions

;; Create a new report template
(define-public (create-template (name (string-ascii 100)) (version (string-ascii 20)) (fields-hash (buff 32)))
  (let
    (
      (template-id (var-get next-template-id))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len version) u0) ERR-INVALID-INPUT)

    (map-set report-templates
      { template-id: template-id }
      {
        name: name,
        version: version,
        fields-hash: fields-hash,
        created-by: tx-sender,
        active: true
      }
    )

    (map-set template-by-name
      { name: name }
      { template-id: template-id }
    )

    (var-set next-template-id (+ template-id u1))
    (ok template-id)
  )
)

;; Create a new report
(define-public (create-report (reporter-id uint) (template-id uint) (report-type (string-ascii 50)) (data-hash (buff 32)))
  (let
    (
      (report-id (var-get next-report-id))
      (template (unwrap! (map-get? report-templates { template-id: template-id }) ERR-INVALID-TEMPLATE))
    )
    (asserts! (> (len report-type) u0) ERR-INVALID-INPUT)
    (asserts! (get active template) ERR-INVALID-TEMPLATE)
    (asserts! (is-reporter-verified-call reporter-id) ERR-REPORTER-NOT-VERIFIED)

    (map-set reports
      { report-id: report-id }
      {
        reporter-id: reporter-id,
        template-id: template-id,
        report-type: report-type,
        data-hash: data-hash,
        created-at: block-height,
        status: u0,
        submitted-at: none
      }
    )

    (var-set next-report-id (+ report-id u1))
    (ok report-id)
  )
)

;; Update report status
(define-public (update-report-status (report-id uint) (new-status uint))
  (let
    (
      (report (unwrap! (map-get? reports { report-id: report-id }) ERR-REPORT-NOT-FOUND))
    )
    (asserts! (< new-status u4) ERR-INVALID-INPUT)

    (map-set reports
      { report-id: report-id }
      (merge report {
        status: new-status,
        submitted-at: (if (is-eq new-status u2) (some block-height) (get submitted-at report))
      })
    )
    (ok true)
  )
)

;; Deactivate template
(define-public (deactivate-template (template-id uint))
  (let
    (
      (template (unwrap! (map-get? report-templates { template-id: template-id }) ERR-INVALID-TEMPLATE))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set report-templates
      { template-id: template-id }
      (merge template { active: false })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get report information
(define-read-only (get-report (report-id uint))
  (map-get? reports { report-id: report-id })
)

;; Get template information
(define-read-only (get-template (template-id uint))
  (map-get? report-templates { template-id: template-id })
)

;; Get template by name
(define-read-only (get-template-by-name (name (string-ascii 100)))
  (match (map-get? template-by-name { name: name })
    template-ref (map-get? report-templates { template-id: (get template-id template-ref) })
    none
  )
)

;; Check if report is submitted
(define-read-only (is-report-submitted (report-id uint))
  (match (map-get? reports { report-id: report-id })
    report (is-eq (get status report) u2)
    false
  )
)

;; Get next report ID
(define-read-only (get-next-report-id)
  (var-get next-report-id)
)

;; Get next template ID
(define-read-only (get-next-template-id)
  (var-get next-template-id)
)

;; Private Functions

;; Check if reporter is verified (simplified for standalone contract)
(define-private (is-reporter-verified-call (reporter-id uint))
  (> reporter-id u0)
)
