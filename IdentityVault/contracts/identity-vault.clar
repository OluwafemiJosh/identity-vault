;; Identity Vault - Soulbound Token (SBT) Smart Contract
;; A decentralized credential system using non-transferable tokens for identity verification

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_TOKEN_NOT_FOUND (err u404))
(define-constant ERR_TOKEN_NON_TRANSFERABLE (err u403))
(define-constant ERR_INVALID_ISSUER (err u402))
(define-constant ERR_ALREADY_ISSUED (err u405))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_TOKEN_REVOKED (err u406))

;; Data structures
(define-map soulbound-tokens
  { token-id: uint }
  {
    owner: principal,
    issuer: principal,
    credential-type: (string-ascii 50),
    title: (string-ascii 100),
    description: (string-ascii 300),
    issued-at: uint,
    expires-at: (optional uint),
    metadata-uri: (string-ascii 200),
    is-revoked: bool,
    verification-level: uint
  }
)

(define-map token-ownership
  { owner: principal, credential-type: (string-ascii 50) }
  { token-id: uint, issued-at: uint }
)

(define-map authorized-issuers
  { issuer: principal, credential-type: (string-ascii 50) }
  {
    is-authorized: bool,
    authorized-at: uint,
    authority-level: uint,
    issued-count: uint
  }
)

(define-map credential-schemas
  { credential-type: (string-ascii 50) }
  {
    name: (string-ascii 100),
    description: (string-ascii 300),
    required-authority-level: uint,
    is-transferable: bool,
    max-validity-period: (optional uint),
    created-at: uint
  }
)

(define-map user-profiles
  { user: principal }
  {
    total-credentials: uint,
    reputation-score: uint,
    first-credential-at: uint,
    verified-credentials: uint
  }
)

;; Data variables
(define-data-var next-token-id uint u1)
(define-data-var total-issued uint u0)
(define-data-var total-revoked uint u0)
(define-data-var registered-credential-types uint u0)

;; Helper functions
(define-private (is-authorized-issuer (issuer principal) (credential-type (string-ascii 50)))
  (let ((issuer-data (map-get? authorized-issuers { issuer: issuer, credential-type: credential-type })))
    (match issuer-data
      some-data (get is-authorized some-data)
      false
    )
  )
)

(define-private (validate-string-input (input (string-ascii 300)))
  (> (len input) u0)
)

(define-private (validate-token-id (token-id uint))
  (and (> token-id u0) (< token-id (var-get next-token-id)))
)

(define-private (validate-authority-level (level uint))
  (and (>= level u1) (<= level u100))
)

(define-private (validate-principal (principal-addr principal))
  (not (is-eq principal-addr (as-contract tx-sender)))
)

(define-private (is-token-expired (token-id uint))
  (let ((token-data (unwrap! (map-get? soulbound-tokens { token-id: token-id }) true)))
    (match (get expires-at token-data)
      some-expiry (>= block-height some-expiry)
      false
    )
  )
)

(define-private (update-user-stats (user principal) (is-new-credential bool))
  (let ((profile (default-to 
    { total-credentials: u0, reputation-score: u100, first-credential-at: block-height, verified-credentials: u0 }
    (map-get? user-profiles { user: user }))))
    
    (if is-new-credential
      (begin
        (map-set user-profiles
          { user: user }
          (merge profile {
            total-credentials: (+ (get total-credentials profile) u1),
            verified-credentials: (+ (get verified-credentials profile) u1),
            reputation-score: (+ (get reputation-score profile) u10)
          })
        )
        true
      )
      true
    )
  )
)

;; Public functions
(define-public (register-credential-type (credential-type (string-ascii 50))
                                        (name (string-ascii 100))
                                        (description (string-ascii 300))
                                        (required-authority-level uint)
                                        (max-validity-blocks (optional uint)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (validate-string-input credential-type) ERR_INVALID_INPUT)
    (asserts! (validate-string-input name) ERR_INVALID_INPUT)
    (asserts! (validate-string-input description) ERR_INVALID_INPUT)
    (asserts! (validate-authority-level required-authority-level) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? credential-schemas { credential-type: credential-type })) ERR_ALREADY_ISSUED)
    
    (map-set credential-schemas
      { credential-type: credential-type }
      {
        name: name,
        description: description,
        required-authority-level: required-authority-level,
        is-transferable: false,
        max-validity-period: max-validity-blocks,
        created-at: block-height
      }
    )
    
    (var-set registered-credential-types (+ (var-get registered-credential-types) u1))
    (ok credential-type)
  )
)

(define-public (authorize-issuer (issuer principal) 
                                (credential-type (string-ascii 50))
                                (authority-level uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (validate-principal issuer) ERR_INVALID_INPUT)
    (asserts! (validate-string-input credential-type) ERR_INVALID_INPUT)
    (asserts! (validate-authority-level authority-level) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? credential-schemas { credential-type: credential-type })) ERR_TOKEN_NOT_FOUND)
    
    (map-set authorized-issuers
      { issuer: issuer, credential-type: credential-type }
      {
        is-authorized: true,
        authorized-at: block-height,
        authority-level: authority-level,
        issued-count: u0
      }
    )
    (ok true)
  )
)

(define-public (issue-credential (recipient principal)
                                (credential-type (string-ascii 50))
                                (title (string-ascii 100))
                                (description (string-ascii 300))
                                (metadata-uri (string-ascii 200))
                                (validity-blocks (optional uint)))
  (let (
    (token-id (var-get next-token-id))
    (schema (unwrap! (map-get? credential-schemas { credential-type: credential-type }) ERR_TOKEN_NOT_FOUND))
    (issuer-auth (unwrap! (map-get? authorized-issuers { issuer: tx-sender, credential-type: credential-type }) ERR_INVALID_ISSUER))
  )
    (asserts! (validate-principal recipient) ERR_INVALID_INPUT)
    (asserts! (validate-string-input credential-type) ERR_INVALID_INPUT)
    (asserts! (validate-string-input title) ERR_INVALID_INPUT)
    (asserts! (validate-string-input description) ERR_INVALID_INPUT)
    (asserts! (validate-string-input metadata-uri) ERR_INVALID_INPUT)
    (asserts! (get is-authorized issuer-auth) ERR_UNAUTHORIZED)
    (asserts! (>= (get authority-level issuer-auth) (get required-authority-level schema)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? token-ownership { owner: recipient, credential-type: credential-type })) ERR_ALREADY_ISSUED)
    
    (let ((expiry-block 
      (match validity-blocks
        some-blocks (some (+ block-height some-blocks))
        (get max-validity-period schema)
      )))
      
      ;; Mint soulbound token
      (map-set soulbound-tokens
        { token-id: token-id }
        {
          owner: recipient,
          issuer: tx-sender,
          credential-type: credential-type,
          title: title,
          description: description,
          issued-at: block-height,
          expires-at: expiry-block,
          metadata-uri: metadata-uri,
          is-revoked: false,
          verification-level: (get authority-level issuer-auth)
        }
      )
      
      ;; Set ownership mapping
      (map-set token-ownership
        { owner: recipient, credential-type: credential-type }
        { token-id: token-id, issued-at: block-height }
      )
      
      ;; Update issuer stats
      (map-set authorized-issuers
        { issuer: tx-sender, credential-type: credential-type }
        (merge issuer-auth { issued-count: (+ (get issued-count issuer-auth) u1) })
      )
      
      ;; Update recipient stats
      (update-user-stats recipient true)
      
      ;; Update global stats
      (var-set next-token-id (+ token-id u1))
      (var-set total-issued (+ (var-get total-issued) u1))
      
      (ok token-id)
    )
  )
)

(define-public (revoke-credential (token-id uint) (reason (string-ascii 200)))
  (let ((token-data (unwrap! (map-get? soulbound-tokens { token-id: token-id }) ERR_TOKEN_NOT_FOUND)))
    (asserts! (validate-token-id token-id) ERR_TOKEN_NOT_FOUND)
    (asserts! (validate-string-input reason) ERR_INVALID_INPUT)
    (asserts! (or (is-eq tx-sender (get issuer token-data)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
    (asserts! (not (get is-revoked token-data)) ERR_TOKEN_REVOKED)
    
    (map-set soulbound-tokens
      { token-id: token-id }
      (merge token-data { is-revoked: true })
    )
    
    ;; Remove ownership mapping
    (map-delete token-ownership 
      { owner: (get owner token-data), credential-type: (get credential-type token-data) }
    )
    
    ;; Update stats
    (var-set total-revoked (+ (var-get total-revoked) u1))
    (ok true)
  )
)

(define-public (verify-credential (owner principal) (credential-type (string-ascii 50)))
  (begin
    (asserts! (validate-principal owner) ERR_INVALID_INPUT)
    (asserts! (validate-string-input credential-type) ERR_INVALID_INPUT)
    
    (let ((ownership (map-get? token-ownership { owner: owner, credential-type: credential-type })))
      (match ownership
        some-ownership 
          (let ((token-data (unwrap! (map-get? soulbound-tokens { token-id: (get token-id some-ownership) }) ERR_TOKEN_NOT_FOUND)))
            (ok {
              is-valid: (and (not (get is-revoked token-data)) (not (is-token-expired (get token-id some-ownership)))),
              token-id: (get token-id some-ownership),
              issuer: (get issuer token-data),
              issued-at: (get issued-at token-data),
              verification-level: (get verification-level token-data)
            })
          )
        (ok {
          is-valid: false,
          token-id: u0,
          issuer: tx-sender,
          issued-at: u0,
          verification-level: u0
        })
      )
    )
  )
)

(define-public (attempt-transfer (token-id uint) (new-owner principal))
  ;; Soulbound tokens are non-transferable by design
  ERR_TOKEN_NON_TRANSFERABLE
)

(define-public (burn-expired-credentials (token-id uint))
  (let ((token-data (unwrap! (map-get? soulbound-tokens { token-id: token-id }) ERR_TOKEN_NOT_FOUND)))
    (asserts! (validate-token-id token-id) ERR_TOKEN_NOT_FOUND)
    (asserts! (is-token-expired token-id) ERR_UNAUTHORIZED)
    
    ;; Remove token data
    (map-delete soulbound-tokens { token-id: token-id })
    (map-delete token-ownership 
      { owner: (get owner token-data), credential-type: (get credential-type token-data) }
    )
    
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-token (token-id uint))
  (map-get? soulbound-tokens { token-id: token-id })
)

(define-read-only (get-user-credential (owner principal) (credential-type (string-ascii 50)))
  (let ((ownership (map-get? token-ownership { owner: owner, credential-type: credential-type })))
    (match ownership
      some-ownership (map-get? soulbound-tokens { token-id: (get token-id some-ownership) })
      none
    )
  )
)

(define-read-only (get-credential-schema (credential-type (string-ascii 50)))
  (map-get? credential-schemas { credential-type: credential-type })
)

(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles { user: user })
)

(define-read-only (is-credential-valid (owner principal) (credential-type (string-ascii 50)))
  (let ((ownership (map-get? token-ownership { owner: owner, credential-type: credential-type })))
    (match ownership
      some-ownership 
        (let ((token-data (map-get? soulbound-tokens { token-id: (get token-id some-ownership) })))
          (match token-data
            some-token (and (not (get is-revoked some-token)) (not (is-token-expired (get token-id some-ownership))))
            false
          )
        )
      false
    )
  )
)

(define-read-only (get-platform-stats)
  (ok {
    total-issued: (var-get total-issued),
    total-revoked: (var-get total-revoked),
    active-credentials: (- (var-get total-issued) (var-get total-revoked)),
    registered-types: (var-get registered-credential-types),
    next-token-id: (var-get next-token-id)
  })
)