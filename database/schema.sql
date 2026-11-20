-- =====================================================================
-- HOSTEL MAINTENANCE AND COMPLAINT TRACKER
-- DATABASE SCHEMA DEFINITION (DDL)
-- Engine: MySQL 8.0+
-- =====================================================================

CREATE DATABASE IF NOT EXISTS hostel_tracker;
USE hostel_tracker;

-- Disable foreign key checks during recreation
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS complaint_history;
DROP TABLE IF EXISTS complaints;
DROP TABLE IF EXISTS staff;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- TABLE: users
-- Core authentication and role-based user management
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL,
    role ENUM('Student', 'Warden', 'Staff') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_phone_len CHECK (CHAR_LENGTH(phone) >= 10)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- TABLE: students
-- Profile details specific to resident students
-- ---------------------------------------------------------------------
CREATE TABLE students (
    student_id INT PRIMARY KEY,
    roll_number VARCHAR(30) NOT NULL UNIQUE,
    hostel_block VARCHAR(20) NOT NULL,
    room_number VARCHAR(20) NOT NULL,
    FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT chk_room_number CHECK (CHAR_LENGTH(room_number) >= 1)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- TABLE: staff
-- Profile details for maintenance personnel
-- ---------------------------------------------------------------------
CREATE TABLE staff (
    staff_id INT PRIMARY KEY,
    specialization ENUM('Plumbing', 'Electrical', 'Carpentry', 'Cleaning', 'Internet/Wi-Fi', 'Appliance', 'General') NOT NULL,
    availability_status ENUM('Active', 'On Leave', 'Inactive') DEFAULT 'Active',
    FOREIGN KEY (staff_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- TABLE: complaints
-- Core complaints logged by students and managed by warden / staff
-- ---------------------------------------------------------------------
CREATE TABLE complaints (
    complaint_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    title VARCHAR(150) NOT NULL,
    category ENUM('Plumbing', 'Electrical', 'Carpentry', 'Cleaning', 'Internet/Wi-Fi', 'Appliance', 'Other') NOT NULL,
    hostel_block VARCHAR(20) NOT NULL,
    room_number VARCHAR(20) NOT NULL,
    description TEXT NOT NULL,
    priority ENUM('Low', 'Medium', 'High', 'Urgent') DEFAULT 'Medium',
    status ENUM('Pending', 'Assigned', 'In Progress', 'Completed', 'Resolved', 'Rejected') DEFAULT 'Pending',
    assigned_staff_id INT NULL,
    warden_notes TEXT NULL,
    staff_notes TEXT NULL,
    complaint_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigned_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    resolved_at TIMESTAMP NULL,
    FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_staff_id) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_complaint_status_date (status, complaint_date),
    INDEX idx_assigned_staff (assigned_staff_id, status),
    INDEX idx_student_complaints (student_id),
    INDEX idx_block_room (hostel_block, room_number)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- TABLE: complaint_history
-- Audit log recording state transitions and maintenance lifecycle
-- ---------------------------------------------------------------------
CREATE TABLE complaint_history (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    complaint_id INT NOT NULL,
    old_status VARCHAR(30) NULL,
    new_status VARCHAR(30) NOT NULL,
    changed_by_user_id INT NULL,
    action_type VARCHAR(50) NOT NULL,
    remarks TEXT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (complaint_id) REFERENCES complaints(complaint_id) ON DELETE CASCADE,
    FOREIGN KEY (changed_by_user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_history_complaint (complaint_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- TABLE: notifications
-- Real-time notifications for students, warden, and staff
-- ---------------------------------------------------------------------
CREATE TABLE notifications (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    complaint_id INT NOT NULL,
    message VARCHAR(255) NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (complaint_id) REFERENCES complaints(complaint_id) ON DELETE CASCADE,
    INDEX idx_user_notifications (user_id, is_read)
) ENGINE=InnoDB;
