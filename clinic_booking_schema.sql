-- ============================================
-- Project: Clinic Booking System
-- Deliverable: Single .sql file with CREATE TABLE statements only
-- Notes:
-- - This file intentionally contains ONLY CREATE TABLE statements (plus comments).
-- - It models 1-1, 1-M, and M-M relationships with proper constraints.
-- - Tested for MySQL 8.x (CHECK constraints are included for clarity; MySQL enforces them from 8.0.16+).
-- ============================================

-- (Optional) If needed in your environment, create and use a database:
-- CREATE DATABASE IF NOT EXISTS clinic_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
-- USE clinic_db;

-- =======================
-- Reference Tables
-- =======================

-- Master list of medical specializations
CREATE TABLE specializations (
  spec_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Medications catalog
CREATE TABLE medications (
  med_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL UNIQUE,
  form ENUM('tablet','capsule','syrup','injection','cream','other') NOT NULL DEFAULT 'tablet',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Insurance providers
CREATE TABLE insurance_providers (
  provider_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL UNIQUE,
  contact_email VARCHAR(150),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Rooms in the clinic
CREATE TABLE rooms (
  room_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(60) NOT NULL UNIQUE,
  type ENUM('consult','surgery','lab','other') NOT NULL DEFAULT 'consult',
  capacity TINYINT UNSIGNED NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =======================
-- Core Entities
-- =======================

-- Patients
CREATE TABLE patients (
  patient_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(60) NOT NULL,
  last_name VARCHAR(60) NOT NULL,
  date_of_birth DATE NOT NULL,
  sex ENUM('M','F','X') NOT NULL,
  phone VARCHAR(30) NOT NULL UNIQUE,
  email VARCHAR(150) UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Doctors
CREATE TABLE doctors (
  doctor_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(60) NOT NULL,
  last_name VARCHAR(60) NOT NULL,
  phone VARCHAR(30) NOT NULL UNIQUE,
  email VARCHAR(150) NOT NULL UNIQUE,
  hire_date DATE NOT NULL,
  license_number VARCHAR(60) NOT NULL UNIQUE,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- M-M: doctors <-> specializations
CREATE TABLE doctor_specializations (
  doctor_id INT UNSIGNED NOT NULL,
  spec_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (doctor_id, spec_id),
  CONSTRAINT fk_docspec_doctor
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_docspec_spec
    FOREIGN KEY (spec_id) REFERENCES specializations(spec_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- A patient may have insurance (M-M with extra attributes possible)
CREATE TABLE patient_insurance (
  patient_id INT UNSIGNED NOT NULL,
  provider_id INT UNSIGNED NOT NULL,
  member_number VARCHAR(100) NOT NULL UNIQUE,
  PRIMARY KEY (patient_id, provider_id),
  CONSTRAINT fk_pins_patient
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_pins_provider
    FOREIGN KEY (provider_id) REFERENCES insurance_providers(provider_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Appointments (1-M: patient -> appointments, doctor -> appointments)
-- Unique (doctor_id, scheduled_at) to avoid double-booking a doctor at the same time
CREATE TABLE appointments (
  appointment_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id INT UNSIGNED NOT NULL,
  doctor_id INT UNSIGNED NOT NULL,
  room_id INT UNSIGNED,
  scheduled_at DATETIME NOT NULL,
  status ENUM('scheduled','checked_in','no_show','cancelled','completed') NOT NULL DEFAULT 'scheduled',
  reason VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_doctor_time (doctor_id, scheduled_at),
  INDEX idx_patient_time (patient_id, scheduled_at),
  CONSTRAINT fk_appt_patient
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_appt_doctor
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_appt_room
    FOREIGN KEY (room_id) REFERENCES rooms(room_id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- Prescriptions: typically tied to an appointment (1-M: appointment -> prescriptions)
CREATE TABLE prescriptions (
  prescription_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  appointment_id INT UNSIGNED NOT NULL,
  issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes VARCHAR(500),
  INDEX idx_presc_appt (appointment_id),
  CONSTRAINT fk_presc_appt
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- M-M: prescriptions <-> medications, with additional attributes
CREATE TABLE prescription_items (
  prescription_id INT UNSIGNED NOT NULL,
  med_id INT UNSIGNED NOT NULL,
  dosage VARCHAR(60) NOT NULL,        -- e.g., 500mg
  frequency VARCHAR(60) NOT NULL,     -- e.g., twice daily
  duration_days SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (prescription_id, med_id),
  CONSTRAINT fk_pitem_presc
    FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_pitem_med
    FOREIGN KEY (med_id) REFERENCES medications(med_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CHECK (duration_days > 0)
) ENGINE=InnoDB;

-- Invoices: 1-1 with appointments (each appointment can produce at most one invoice)
CREATE TABLE invoices (
  invoice_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  appointment_id INT UNSIGNED NOT NULL UNIQUE,  -- enforces 1-1 relationship
  patient_id INT UNSIGNED NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL,
  status ENUM('unpaid','paid','void') NOT NULL DEFAULT 'unpaid',
  issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_inv_patient (patient_id),
  CONSTRAINT fk_inv_appt
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_inv_patient
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CHECK (total_amount >= 0)
) ENGINE=InnoDB;

-- Payments: 1-M with invoices
CREATE TABLE payments (
  payment_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  invoice_id INT UNSIGNED NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  method ENUM('cash','card','mpesa','insurance','bank') NOT NULL,
  paid_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_pay_invoice (invoice_id),
  CONSTRAINT fk_pay_invoice
    FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CHECK (amount > 0)
) ENGINE=InnoDB;
