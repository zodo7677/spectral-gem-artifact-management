;; spectral-gem-framework -  comprehensive access control and artifact lifecycle management

;; Primary system administrator established at deployment
(define-constant NEXUS-OVERSEER tx-sender)

;; System response indicators for operational states
(define-constant ERR-ARTIFACT-NOT-FOUND (err u301))
(define-constant ERR-INVALID-RECIPIENT (err u306))
(define-constant ERR-OPERATION-FORBIDDEN (err u307))
(define-constant ERR-ACCESS-DENIED (err u308))
(define-constant ERR-ARTIFACT-DUPLICATE (err u302))
(define-constant ERR-VALUE-OUT-OF-RANGE (err u304))
(define-constant ERR-INSUFFICIENT-PRIVILEGES (err u305))
(define-constant ERR-IDENTIFIER-MALFORMED (err u303))

;; Tracks current artifact sequence number
(define-data-var artifact-sequence-tracker uint u0)

;; Core artifact data storage structure
(define-map quantum-artifact-vault
  { artifact-id: uint }
  {
    artifact-identifier: (string-ascii 64),
    current-guardian: principal,
    power-rating: uint,
    creation-timestamp: uint,
    artifact-lore: (string-ascii 128),
    attribute-tags: (list 10 (string-ascii 32))
  }
)

;; Access permission matrix for artifact viewing rights
(define-map guardian-access-matrix
  { artifact-id: uint, requesting-entity: principal }
  { access-authorized: bool }
)

;; Verification function for artifact existence in vault
(define-private (artifact-exists-in-vault (artifact-id uint))
  (is-some (map-get? quantum-artifact-vault { artifact-id: artifact-id }))
)

;; Individual attribute tag validation function
(define-private (validate-single-tag (tag-content (string-ascii 32)))
  (and 
    (> (len tag-content) u0)
    (< (len tag-content) u33)
  )
)

;; Complete attribute tag collection validation
(define-private (validate-tag-collection (tag-list (list 10 (string-ascii 32))))
  (and
    (> (len tag-list) u0)
    (<= (len tag-list) u10)
    (is-eq (len (filter validate-single-tag tag-list)) (len tag-list))
  )
)

;; String content boundary validation utility
(define-private (check-string-limits (input-string (string-ascii 64)) (min-chars uint) (max-chars uint))
  (and 
    (>= (len input-string) min-chars)
    (<= (len input-string) max-chars)
  )
)

;; Guardian authorization verification function
(define-private (verify-guardian-rights (artifact-id uint) (guardian-address principal))
  (match (map-get? quantum-artifact-vault { artifact-id: artifact-id })
    artifact-record (is-eq (get current-guardian artifact-record) guardian-address)
    false
  )
)

;; Power rating extraction utility
(define-private (get-artifact-power (artifact-id uint))
  (default-to u0 
    (get power-rating 
      (map-get? quantum-artifact-vault { artifact-id: artifact-id })
    )
  )
)

;; Sequence tracker increment function
(define-private (increment-artifact-sequence)
  (let ((current-sequence (var-get artifact-sequence-tracker)))
    (var-set artifact-sequence-tracker (+ current-sequence u1))
    (ok current-sequence)
  )
)

;; Primary artifact registration interface
(define-public (forge-new-artifact (artifact-identifier (string-ascii 64)) (power-rating uint) (artifact-lore (string-ascii 128)) (attribute-tags (list 10 (string-ascii 32))))
  (let
    (
      (next-artifact-id (+ (var-get artifact-sequence-tracker) u1))
    )
    ;; Comprehensive input validation protocol
    (asserts! (and (> (len artifact-identifier) u0) (< (len artifact-identifier) u65)) ERR-IDENTIFIER-MALFORMED)
    (asserts! (and (> power-rating u0) (< power-rating u1000000000)) ERR-VALUE-OUT-OF-RANGE)
    (asserts! (and (> (len artifact-lore) u0) (< (len artifact-lore) u129)) ERR-IDENTIFIER-MALFORMED)
    (asserts! (validate-tag-collection attribute-tags) ERR-IDENTIFIER-MALFORMED)

    ;; Store artifact in quantum vault
    (map-insert quantum-artifact-vault
      { artifact-id: next-artifact-id }
      {
        artifact-identifier: artifact-identifier,
        current-guardian: tx-sender,
        power-rating: power-rating,
        creation-timestamp: block-height,
        artifact-lore: artifact-lore,
        attribute-tags: attribute-tags
      }
    )

    ;; Grant initial access permissions to creator
    (map-insert guardian-access-matrix
      { artifact-id: next-artifact-id, requesting-entity: tx-sender }
      { access-authorized: true }
    )

    ;; Update global sequence tracker
    (var-set artifact-sequence-tracker next-artifact-id)
    (ok next-artifact-id)
  )
)

;; Artifact lore retrieval function
(define-public (retrieve-artifact-lore (artifact-id uint))
  (let
    (
      (artifact-data (unwrap! (map-get? quantum-artifact-vault { artifact-id: artifact-id }) ERR-ARTIFACT-NOT-FOUND))
    )
    (ok (get artifact-lore artifact-data))
  )
)

;; Access permission verification interface
(define-public (check-entity-access (artifact-id uint) (requesting-entity principal))
  (let
    (
      (access-record (map-get? guardian-access-matrix { artifact-id: artifact-id, requesting-entity: requesting-entity }))
    )
    (ok (is-some access-record))
  )
)

;; Attribute tag quantity calculation
(define-public (count-artifact-tags (artifact-id uint))
  (let
    (
      (artifact-data (unwrap! (map-get? quantum-artifact-vault { artifact-id: artifact-id }) ERR-ARTIFACT-NOT-FOUND))
    )
    (ok (len (get attribute-tags artifact-data)))
  )
)

;; Identifier format validation interface
(define-public (verify-identifier-structure (artifact-identifier (string-ascii 64)))
  (ok (and (> (len artifact-identifier) u0) (<= (len artifact-identifier) u64)))
)

;; Guardian transfer protocol
(define-public (transfer-guardianship (artifact-id uint) (new-guardian principal))
  (let
    (
      (artifact-data (unwrap! (map-get? quantum-artifact-vault { artifact-id: artifact-id }) ERR-ARTIFACT-NOT-FOUND))
    )
    (asserts! (artifact-exists-in-vault artifact-id) ERR-ARTIFACT-NOT-FOUND)
    (asserts! (is-eq (get current-guardian artifact-data) tx-sender) ERR-INSUFFICIENT-PRIVILEGES)

    ;; Update guardian information in vault
    (map-set quantum-artifact-vault
      { artifact-id: artifact-id }
      (merge artifact-data { current-guardian: new-guardian })
    )
    (ok true)
  )
)

;; Comprehensive artifact modification interface
(define-public (modify-artifact-properties (artifact-id uint) (new-identifier (string-ascii 64)) (new-power-rating uint) (new-lore (string-ascii 128)) (new-tags (list 10 (string-ascii 32))))
  (let
    (
      (artifact-data (unwrap! (map-get? quantum-artifact-vault { artifact-id: artifact-id }) ERR-ARTIFACT-NOT-FOUND))
    )
    ;; Multi-layer validation system
    (asserts! (artifact-exists-in-vault artifact-id) ERR-ARTIFACT-NOT-FOUND)
    (asserts! (is-eq (get current-guardian artifact-data) tx-sender) ERR-INSUFFICIENT-PRIVILEGES)
    (asserts! (and (> (len new-identifier) u0) (< (len new-identifier) u65)) ERR-IDENTIFIER-MALFORMED)
    (asserts! (and (> new-power-rating u0) (< new-power-rating u1000000000)) ERR-VALUE-OUT-OF-RANGE)
    (asserts! (and (> (len new-lore) u0) (< (len new-lore) u129)) ERR-IDENTIFIER-MALFORMED)
    (asserts! (validate-tag-collection new-tags) ERR-IDENTIFIER-MALFORMED)

    ;; Apply modifications to vault record
    (map-set quantum-artifact-vault
      { artifact-id: artifact-id }
      (merge artifact-data { 
        artifact-identifier: new-identifier, 
        power-rating: new-power-rating, 
        artifact-lore: new-lore, 
        attribute-tags: new-tags 
      })
    )
    (ok true)
  )
)

;; Artifact removal protocol
(define-public (destroy-artifact (artifact-id uint))
  (let
    (
      (artifact-data (unwrap! (map-get? quantum-artifact-vault { artifact-id: artifact-id }) ERR-ARTIFACT-NOT-FOUND))
    )
    (asserts! (artifact-exists-in-vault artifact-id) ERR-ARTIFACT-NOT-FOUND)
    (asserts! (is-eq (get current-guardian artifact-data) tx-sender) ERR-INSUFFICIENT-PRIVILEGES)

    ;; Remove artifact from quantum vault
    (map-delete quantum-artifact-vault { artifact-id: artifact-id })
    (ok true)
  )
)

