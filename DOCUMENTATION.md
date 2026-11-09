# Hospital Management & Authentication System
## System Architecture, Cryptographic Security & Admin Operations Manual

---

## 1. Introduction

### 1.1 Purpose of the Document
This document provides a comprehensive technical and operational reference for the **Hospital Management & Authentication System**. It is structured for software architects, systems engineers, medical administrators, and security compliance auditors. The document details the software architecture, the cryptographic password-protection mechanism (featuring **Salts** and **Peppers**), multi-factor email verification workflows, and all clinical and administrative operations available within the **Admin Dashboard**.

### 1.2 System Overview
The platform is an enterprise-grade hospital information and identity management portal developed on a Node.js (Express 5) backend, a high-performance SQLite database operating in **Write-Ahead Logging (WAL)** mode, and a responsive frontend client. The system manages clinical interactions and sensitive Protected Health Information (PHI) across six distinct hospital roles:

1. **Administrator (`admin`)**: Complete system oversight, account creation/modification, custom role provisioning, cryptographic audits, automated database backups, disaster recovery, and PDF/Excel compliance reporting.
2. **Doctor (`doctor`)**: Clinical consultations, diagnoses, prescription issuance, and review of patient care requests.
3. **Nurse (`nurse`)**: Patient triage, vital signs measurement (blood pressure, heart rate, temperature), and observation logging.
4. **Patient (`patient`)**: Patient care portal, personal medical records, vitals history, and consultation requests.
5. **Manager (`manager`)**: Department operations review and activity log tracking.
6. **Imputor (`imputor`)**: Transactional record and data entry processing.

### 1.3 Key Objectives & Compliance Alignment
- **NIST SP 800-63B & OWASP Zero-Knowledge Standards**: Plaintext user passwords are never stored, logged, transmitted, or retrievable.
- **Two-Tier Cryptographic Credential Protection**: Per-user cryptographically random **Salt** combined with an isolated application **Pepper**.
- **Defense-in-Depth Authentication**: Two-step email verification (HMAC-SHA256 OTP) with brute-force lockouts and session hijacking prevention.
- **Data Integrity & Disaster Resilience**: Real-time SQLite WAL backups, offline encrypted downloads (AES-256-GCM via HKDF), automated email dispatch, and AWS S3 cloud replication.

---

## 2. Body

### 2.1 Cryptographic Architecture: Salt and Pepper Implementation

A core security requirement of this platform is the prevention of credential recovery, rainbow table attacks, and offline brute-force cracking even in the event of an unauthorized database breach.

```
+-----------------------------------------------------------------------------------------+
|                               PASSWORD HASHING WORKFLOW                                 |
+-----------------------------------------------------------------------------------------+
|                                                                                         |
|   [ Plaintext Password ]                                                                |
|            +                                                                            |
|   [ Application Pepper ] ───► (Server-Side Secret: PASSWORD_PEPPER >= 32 chars in .env) |
|            │                                                                            |
|            ▼                                                                            |
|   Concatenated Secret String: `${password}${passwordPepper}`                            |
|            │                                                                            |
|            ├─────────────────────────────────────────┐                                  |
|            ▼                                         ▼                                  |
|   [ CSPRNG Salt (16 bytes) ]             [ scrypt KDF Parameters ]                      |
|   (crypto.randomBytes(16)                 • N = 32768 (CPU/Memory Cost: 2^15)           |
|    = 32 hex characters)                   • r = 8 (Block Size)                          |
|            │                              • p = 1 (Parallelization)                     |
|            │                              • Output Length = 64 bytes (512 bits)         |
|            │                              • maxmem = 64 MB                              |
|            ▼                                         │                                  |
|   [ crypto.scrypt(...) ] ◄───────────────────────────┘                                  |
|            │                                                                            |
|            ▼                                                                            |
|   Derived Hash (64 bytes / 128 hex chars)                                               |
|            │                                                                            |
|            ▼                                                                            |
|   PERSISTED TO DATABASE (`users` table):                                                |
|   - `password_hash`: 128 hexadecimal characters                                         |
|   - `password_salt`: 32 hexadecimal characters                                          |
|   - (Plaintext password is wiped immediately from memory)                               |
+-----------------------------------------------------------------------------------------+
```

#### 2.1.1 Cryptographic Salt (`password_salt`)
- **Nature**: A unique, cryptographically random 16-byte (128-bit) binary value generated per account using `crypto.randomBytes(16)`.
- **Representation**: Stored as a 32-character hexadecimal string in the `password_salt` column of the `users` SQLite database.
- **Function**: Guarantees that two users with identical passwords produce completely distinct hashes, neutralizing precomputed dictionary attacks and rainbow tables.

#### 2.1.2 Cryptographic Pepper (`passwordPepper`)
- **Nature**: A high-entropy, 32+ character secret key injected at runtime via the `PASSWORD_PEPPER` environment variable.
- **Storage**: Never written to the database or logged. It resides strictly within the host execution environment or hardware secret vault.
- **Function**: Adds an external tier of defense. If the database file (`app.db`) is leaked or extracted through an unauthorized backup dump, an attacker cannot compute or verify password hashes because the derivation relies on the server-side pepper.

#### 2.1.3 Password Verification & Timing-Attack Mitigation
During user authentication:
1. The server queries the database for the user record by email and role.
2. The user's stored salt is converted from hex: `Buffer.from(user.password_salt, 'hex')`.
3. The server executes `scrypt` using the submitted plaintext password concatenated with `passwordPepper` and the user's stored salt.
4. The generated buffer is evaluated against the stored hash using `crypto.timingSafeEqual(expected, actual)`. This constant-time comparison eliminates side-channel timing attacks.

---

### 2.2 End-to-End Authentication & Two-Step Verification Flow

Authentication adheres to a strict multi-tier verification process:

```
[ Step 1: Login Form ]
   │  User submits Email, Password, and Role selection.
   ▼
[ Credential Verification ]
   │  scrypt timing-safe password evaluation against stored hash, salt & pepper.
   ▼
[ Step 2: One-Time Passcode (OTP) Generation ]
   │  Server generates 6-digit random code (5-minute TTL).
   │  Digest created: HMAC-SHA256(sessionSecret, `${tokenHash}:${code}`).
   │  Code dispatched via Resend HTTPS (Port 443) or direct SMTP.
   ▼
[ Step 3: Two-Factor Verification Challenge ]
   │  User inputs the 6-digit OTP received in their inbox.
   │  Server enforces rate limiting (max 5 failed attempts, 60-second resend cooldown).
   ▼
[ Session Established ]
   │  Session elevated to `complete` stage.
   │  Secure HTTP-only, SameSite=Strict cookie assigned (`login_session`, 8-hour lifetime).
   ▼
[ Role-Based Dashboard Redirection ]
```

---

### 2.3 The Admin Executive Dashboard

The Admin Dashboard provides comprehensive tools for clinical data governance, credential security audits, automated backup management, and disaster recovery.

---

#### 2.3.1 Executive Toolbar & Hospital Snapshot
The dashboard header displays the high-level operational metrics of the hospital facility. It features an interactive **View PDF Document** button generating on-the-fly executive reports, alongside a visual status summary.

> **[ SCREENSHOT PLACEHOLDER 1: Admin Dashboard Executive Overview & Hospital Snapshot ]**  
> *Recommended File Name: `admin_dashboard_overview.png`*  
> *Caption: Executive administration view showing the Hospital Snapshot metrics grid (Total Accounts, Doctors, Nurses, Patients, Consultations, and Vitals Logs), doctor profile image, and export controls.*  
> *(Insert screenshot showing the top of the Admin Dashboard here)*

**Key Elements Displayed:**
- **Metric Cards**: Total Accounts, Registered Doctors, Nurses, Patients, Clinical Consultations, and Vitals Logs.
- **Report Generation**: Direct link to `/api/admin/report/pdf` producing an audit report with cryptographic checksums.

---

#### 2.3.2 Accounts & Credential Security Directory (Salt & Hash Inspector)
This panel provides complete visibility into user accounts, password security compliance, and cryptographic parameters without compromising zero-knowledge principles.

> **[ SCREENSHOT PLACEHOLDER 2: Accounts & Credential Security Directory ]**  
> *Recommended File Name: `admin_credential_security_directory.png`*  
> *Caption: Accounts table displaying authenticated users, role badges, "Never Stored" zero-knowledge security pills, scrypt password hashes, and isolated cryptographic salts with one-click copy buttons.*  
> *(Insert screenshot of the Accounts Directory table here)*

**Key Elements Displayed:**
- **Role Filters**: Quick filtering by All Accounts, Doctors, Nurses, Patients, and Administrators.
- **Plaintext Password Column**: Demonstrates the `🛡️ Never Stored` Zero-Knowledge compliance badge.
- **Password Hash Column**: Displays truncated 128-hex character `scrypt` verifiers with a dedicated **Copy** button.
- **Cryptographic Salt Column**: Displays truncated 32-hex character per-user salts with a dedicated **Copy** button.
- **Action Controls**:
  - `AUDIT`: Launches the full-screen Credential & Infosec Inspector Modal.
  - `MODIFY`: Allows changing display names, emails, and roles.
  - `DELETE`: Opens the safe deletion confirmation modal.

---

#### 2.3.3 Credential Security Audit Modal
Clicking **AUDIT** on any user account launches an in-depth modal inspection window detailing the cryptographic specifications for that account.

> **[ SCREENSHOT PLACEHOLDER 3: Credential Audit & Infosec Inspector Modal ]**  
> *Recommended File Name: `admin_credential_audit_modal.png`*  
> *Caption: Full credential audit modal illustrating the complete 128-character scrypt password hash, 32-character CSPRNG salt, RFC 7914 specifications, and defense-in-depth pepper parameters.*  
> *(Insert screenshot of the Credential Audit modal here)*

**Specifications Verified in Modal:**
- Full 128-character hexadecimal scrypt hash.
- Full 32-character hexadecimal cryptographic salt.
- Memory cost parameters ($N=32768$, $r=8$, $p=1$, Derived Key Length = 64 bytes).
- Confirmation of server-side pepper concatenation.

---

#### 2.3.4 Dynamic Role Management & Data Persistence Archive
The Admin Dashboard allows creating, modifying, and safely archiving system roles.

> **[ SCREENSHOT PLACEHOLDER 4: Role Management & Archived Roles Panel ]**  
> *Recommended File Name: `admin_role_management.png`*  
> *Caption: Role management table showing active roles, assigned permissions, user counts, and the Safely Archived Roles panel.*  
> *(Insert screenshot of the Role Management section here)*

**Features:**
- **Create Role (`ADD`)**: Configures role key, display name, description, and permission scope.
- **Modify Role (`MODIFY`)**: Updates role descriptions and privilege boundaries without breaking existing user links.
- **Safe Archiving (`DELETE`)**: Deleting a role prompts a confirmation modal (`YES`/`NO`). Decommissioned roles are migrated to the `archived_roles` table, guaranteeing that historical patient records and audit trails maintain relational integrity.
- **Excel Archive Export**: Exports all archived roles to `.xlsx` spreadsheet format.

---

#### 2.3.5 Backup, Disaster Recovery & Active Backup Viewer
The system maintains automated and on-demand disaster recovery pipelines.

> **[ SCREENSHOT PLACEHOLDER 5: Backup & Restore Management Panel ]**  
> *Recommended File Name: `admin_backup_management.png`*  
> *Caption: Active Backup Viewer showing real-time snapshot file details, timestamp, file size, integrity checks, and cloud/offline backup options.*  
> *(Insert screenshot of the Backup & Restore Management section here)*

**Disaster Recovery Capabilities:**
- **Active Backup Viewer**: Displays the live SQLite snapshot filename (`app-backup-live-latest.db`), file size in KB, creation timestamp, and active user/role counts.
- **Download Offline Backup (`.enc`)**: Downloads an encrypted backup encrypted with **AES-256-GCM** using an encryption key derived via HKDF-SHA256 from the application session secret.
- **Email Encrypted Backup**: Compresses, encrypts, and delivers the database backup directly to the administrative inbox.
- **AWS S3 Cloud Backup**: Uploads snapshots with server-side AES-256 encryption to Amazon S3 buckets.
- **System Restore**: Allows selecting historical backup archives from local storage or AWS S3 to restore the system state with a safety rollback guarantee.

---

#### 2.3.6 Login Audit Trail & Daily Activity Log
Every authentication action is logged into the `login_audit_trail` table.

> **[ SCREENSHOT PLACEHOLDER 6: Login Audit Trail & Activity Log ]**  
> *Recommended File Name: `admin_login_audit_trail.png`*  
> *Caption: Login Audit Trail interface detailing authentication statuses, user emails, roles, originating IP addresses, client user agents, and exact timestamps.*  
> *(Insert screenshot of the Login Audit Trail table here)*

**Audit Status Classifications:**
- `LOGIN_SUCCESS`: Successful authentication and completed 2FA challenge.
- `LOGIN_PASSWORD_FAILED`: Invalid password submission.
- `OTP_FAILED`: Incorrect one-time verification code entered.
- `OTP_LOCKED_OUT`: Exceeded 5 failed verification attempts; account session locked.
- `PASSWORD_RESET_COMPLETED`: Password recovery successfully finalized.

---

#### 2.3.7 Clinical Oversight Panels
Administrators have cross-department visibility into daily clinical records:
1. **Doctor Clinical Consultations & Diagnoses**: Displays patient emails, attending doctors, diagnosed conditions, medications prescribed, and clinical notes.
2. **Nurse Vitals & Observations Log**: Displays patient triage observations including blood pressure (BP), heart rate (BPM), body temperature (°C/°F), and recorded notes.
3. **Patient Care Requests & Inquiries**: Displays consultation requests, subject lines, and patient messages.

---

## 3. Conclusion

### 3.1 Technical Summary
The **Hospital Management & Authentication System** establishes a secure, compliant environment for managing patient data and clinical operations. By implementing **scrypt** with per-user **Salts** and an application **Pepper**, the platform satisfies the highest modern cryptographic standards for password security. Coupled with two-step email verification, role-based authorization, immutable audit logging, and automated AES-256-GCM disaster recovery, the system guarantees the Confidentiality, Integrity, and Availability (CIA Triad) of hospital data.

### 3.2 Operational Recommendations
1. **Pepper Isolation**: In production deployments, store `PASSWORD_PEPPER` within an enterprise secret vault (e.g., AWS Secrets Manager, HashiCorp Vault) rather than a plaintext configuration file.
2. **Regular Backup Drills**: Perform quarterly restore simulations using the system's AWS S3 and offline `.enc` restore functions to validate recovery time objectives (RTO).
3. **Audit Log Monitoring**: Review the Login Audit Trail weekly for repetitive `OTP_LOCKED_OUT` or `LOGIN_PASSWORD_FAILED` events originating from unfamiliar IP addresses.
