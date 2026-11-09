-- =====================================================================
-- NEON POSTGRESQL SCHEMA FOR HOSPITAL MANAGEMENT & AUTHENTICATION SYSTEM
-- Compatible with Vercel Serverless & Neon Serverless Postgres (@neondatabase/serverless)
-- =====================================================================

-- 1. ROLES TABLE
CREATE TABLE IF NOT EXISTS roles (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL UNIQUE,
  display_name VARCHAR(100) NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  permissions VARCHAR(255) NOT NULL DEFAULT 'Standard',
  is_system INT NOT NULL DEFAULT 0,
  is_archived INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. ARCHIVED ROLES TABLE
CREATE TABLE IF NOT EXISTS archived_roles (
  id SERIAL PRIMARY KEY,
  original_role_id INT NOT NULL,
  name VARCHAR(50) NOT NULL,
  display_name VARCHAR(100) NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  permissions VARCHAR(255) NOT NULL DEFAULT 'Standard',
  user_count_at_archive INT NOT NULL DEFAULT 0,
  archived_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  archived_by VARCHAR(100) NOT NULL DEFAULT 'admin',
  archive_reason TEXT NOT NULL DEFAULT 'Admin user deletion'
);

-- Seed Initial System Roles
INSERT INTO roles (name, display_name, description, permissions, is_system)
VALUES 
  ('admin', 'Administrator', 'Overall system administrator with full access to accounts, roles, backups, and audit reports.', 'Full System Control (Admin)', 1),
  ('doctor', 'Doctor', 'Healthcare provider who diagnoses patients and prescribes medications.', 'Clinical Consultations & Prescriptions', 1),
  ('nurse', 'Nurse', 'Clinical staff who triages patients, records vital signs, and reviews requests.', 'Vitals & Triage Care', 1),
  ('patient', 'Patient', 'Registered hospital patient who can review medical records, vitals, and submit requests.', 'Patient Portal Access', 1),
  ('manager', 'Manager', 'Hospital department oversight and operational workflow monitoring.', 'Management Oversight & Logs', 1),
  ('imputor', 'Imputor', 'Operational data entry staff who logs hospital transaction entries.', 'Operational Data Entry', 1)
ON CONFLICT (name) DO NOTHING;

-- 3. USERS TABLE
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(255) NOT NULL,
  password_hash TEXT NOT NULL,
  password_salt TEXT NOT NULL,
  role VARCHAR(50) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  email_verified INT NOT NULL DEFAULT 1,
  CONSTRAINT uq_username_role UNIQUE(username, role)
);

-- 4. LOGIN AUDIT TRAIL
CREATE TABLE IF NOT EXISTS login_audit_trail (
  id SERIAL PRIMARY KEY,
  username VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL DEFAULT 'unknown',
  status VARCHAR(100) NOT NULL,
  ip_address VARCHAR(100),
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_login_audit_trail_created_at ON login_audit_trail(created_at DESC);

-- 5. SESSIONS TABLE
CREATE TABLE IF NOT EXISTS sessions (
  token_hash VARCHAR(128) PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  stage VARCHAR(20) NOT NULL CHECK (stage IN ('setup', 'verify', 'complete')),
  expires_at BIGINT NOT NULL,
  email_code_hash TEXT,
  email_code_expires_at BIGINT,
  email_code_attempts INT NOT NULL DEFAULT 0,
  email_code_sent_at BIGINT
);

-- 6. ENTRIES TABLE (Manager / Imputor)
CREATE TABLE IF NOT EXISTS entries (
  id SERIAL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  created_by INT NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 7. MEDICAL RECORDS (Doctor Consultations)
CREATE TABLE IF NOT EXISTS medical_records (
  id SERIAL PRIMARY KEY,
  patient_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  doctor_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  diagnosis VARCHAR(255) NOT NULL,
  prescription TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 8. VITALS (Nurse Triage)
CREATE TABLE IF NOT EXISTS vitals (
  id SERIAL PRIMARY KEY,
  patient_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  nurse_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blood_pressure VARCHAR(50) NOT NULL,
  heart_rate VARCHAR(50) NOT NULL,
  temperature VARCHAR(50) NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 9. PATIENT REQUESTS (Patient Inquiries)
CREATE TABLE IF NOT EXISTS patient_requests (
  id SERIAL PRIMARY KEY,
  patient_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 10. PASSWORD RESETS
CREATE TABLE IF NOT EXISTS password_resets (
  token_hash VARCHAR(128) PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_hash TEXT,
  code_expires_at BIGINT,
  code_attempts INT NOT NULL DEFAULT 0,
  code_sent_at BIGINT,
  verified INT NOT NULL DEFAULT 0,
  created_at BIGINT NOT NULL,
  expires_at BIGINT NOT NULL
);
