# Identity Vault

A decentralized Soulbound Token (SBT) system built with Clarity smart contracts that enables the creation and management of non-transferable credentials for identity verification, achievements, and reputation tracking.

## Overview

Identity Vault addresses the need for verifiable, tamper-proof digital credentials that are permanently bound to their owners. Unlike traditional NFTs, Soulbound Tokens cannot be transferred, making them perfect for representing identity, achievements, certifications, and reputation that should remain tied to a specific individual or entity.

## Features

- **Non-Transferable Tokens**: True soulbound implementation preventing any transfers
- **Flexible Credential Types**: Support for education, professional, identity, and achievement credentials
- **Authorized Issuer System**: Only verified entities can issue specific credential types
- **Expiration Management**: Time-limited credentials with automatic expiration handling
- **Revocation System**: Issuers can invalidate credentials when necessary
- **Reputation Tracking**: User profiles with credential history and trust scores
- **Comprehensive Verification**: Easy third-party credential validation

## Quick Start

### Registering Credential Types (Owner Only)

```clarity
;; Register a new credential type
(contract-call? .identity-vault register-credential-type 
  "university-degree"
  "University Degree"
  "Official university degree certification"
  u50  ;; authority level required
  (some u525600)) ;; ~1 year validity
```

### Authorizing Issuers

```clarity
;; Authorize university to issue degrees
(contract-call? .identity-vault authorize-issuer
  'SP-UNIVERSITY-ADDRESS
  "university-degree"
  u75) ;; authority level
```

### Issuing Credentials

```clarity
;; University issues degree to graduate
(contract-call? .identity-vault issue-credential
  'SP-GRADUATE-ADDRESS
  "university-degree"
  "Bachelor of Computer Science"
  "Degree in Computer Science from University XYZ"
  "https://university.edu/credentials/12345"
  (some u525600)) ;; validity period
```

### Verifying Credentials

```clarity
;; Verify someone's degree
(contract-call? .identity-vault verify-credential
  'SP-GRADUATE-ADDRESS
  "university-degree")
```

## Core Functions

| Function | Access | Description |
|----------|--------|-------------|
| `register-credential-type` | Owner | Define new credential categories |
| `authorize-issuer` | Owner | Grant issuing permissions |
| `issue-credential` | Authorized Issuer | Mint soulbound tokens |
| `revoke-credential` | Issuer/Owner | Invalidate credentials |
| `verify-credential` | Public | Check credential validity |
| `attempt-transfer` | Public | Always fails (SBT property) |
| `burn-expired-credentials` | Public | Clean up expired tokens |

## Credential Categories

### Educational Credentials
- **University Degrees**: Bachelor's, Master's, PhD certifications
- **Course Completions**: Professional courses, online certifications
- **Academic Achievements**: Dean's list, honors, academic awards

### Professional Credentials
- **Licenses**: Medical, legal, engineering licenses
- **Certifications**: Industry-specific skill certifications
- **Employment Verification**: Work history, role confirmations

### Identity Verification
- **KYC Credentials**: Know Your Customer verification
- **Age Verification**: Age-gated service access
- **Residency Proof**: Location-based service eligibility

### Achievement & Reputation
- **Community Awards**: Recognition for contributions
- **Skill Badges**: Demonstrated competencies
- **Trust Scores**: Community-validated reputation

## Security Features

- **Input Validation**: All user inputs thoroughly validated
- **Authority Hierarchy**: Tiered permission system (1-100 levels)
- **Expiration Enforcement**: Automatic credential lifecycle management
- **Revocation Controls**: Only issuers or contract owner can revoke
- **Transfer Prevention**: Cryptographically enforced non-transferability
- **One-Per-Type Limit**: Users limited to one credential per type

## Use Cases

### Academic Institutions
```clarity
;; Issue diploma that cannot be forged or transferred
(contract-call? .identity-vault issue-credential
  student-address "diploma" "MBA" "Master of Business Administration" metadata-uri none)
```

### Professional Licensing
```clarity
;; Medical board issues doctor license
(contract-call? .identity-vault issue-credential
  doctor-address "medical-license" "MD License" "Licensed Medical Doctor" metadata-uri (some validity))
```

### Platform Verification
```clarity
;; Verify user has required certification
(let ((verification (unwrap! (contract-call? .identity-vault verify-credential user "certification") false)))
  (get is-valid verification))
```

## Error Codes

- `u401` - Unauthorized access
- `u404` - Token/credential not found
- `u403` - Non-transferable token (SBT property)
- `u402` - Invalid issuer credentials
- `u405` - Credential already issued
- `u400` - Invalid input data
- `u406` - Token already revoked

## Data Structure

### Token Properties
- **Owner**: Credential holder (immutable)
- **Issuer**: Credential issuer (verified)
- **Type**: Credential category
- **Metadata**: Title, description, URI
- **Validity**: Issue date, expiration
- **Status**: Active, revoked, expired

### User Profiles
- **Credential Count**: Total credentials held
- **Reputation Score**: Community trust rating
- **Verification Status**: Validated credentials count
- **Activity History**: First credential date

## Best Practices

### For Contract Owners
- Carefully vet issuers before authorization
- Set appropriate authority levels for credential types
- Monitor for fraudulent credential issuance
- Maintain clear revocation policies

### For Issuers
- Verify recipient identity before issuing
- Use clear, descriptive credential titles
- Include comprehensive metadata URIs
- Set appropriate validity periods

### For Recipients
- Protect private keys (credentials cannot be recovered if lost)
- Understand credential expiration dates
- Maintain good standing with issuing organizations
- Use credentials responsibly for verification

## Integration Examples

### Employment Verification
```clarity
(define-read-only (verify-employee-skills (candidate principal))
  (let (
    (degree (contract-call? .identity-vault verify-credential candidate "university-degree"))
    (certification (contract-call? .identity-vault verify-credential candidate "professional-cert"))
  )
    (and (get is-valid degree) (get is-valid certification))
  )
)
```

### Age-Gated Services
```clarity
(define-read-only (verify-age-requirement (user principal))
  (let ((age-credential (contract-call? .identity-vault verify-credential user "age-verification")))
    (get is-valid age-credential)
  )
)
```

## Testing

Comprehensive test coverage should include:
- Credential type registration and validation
- Issuer authorization workflows
- Credential issuance and verification
- Transfer prevention mechanisms
- Expiration and revocation scenarios
- Input validation and error handling

## Contributing

This project is designed for blockchain competitions and real-world identity systems. Contributions welcome for:
- Additional credential types and schemas
- Enhanced verification mechanisms
- Integration with external identity providers
- Privacy-preserving verification methods