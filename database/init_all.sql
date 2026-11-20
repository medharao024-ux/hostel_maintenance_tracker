-- =====================================================================
-- HOSTEL MAINTENANCE AND COMPLAINT TRACKER
-- ALL-IN-ONE MASTER DATABASE INITIALIZER (FOR MYSQL WORKBENCH)
-- Open this file in MySQL Workbench and click the ⚡ Lightning Bolt!
-- =====================================================================

CREATE DATABASE IF NOT EXISTS hostel_tracker;
USE hostel_tracker;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS complaint_history;
DROP TABLE IF EXISTS complaints;
DROP TABLE IF EXISTS staff;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS users;

DROP VIEW IF EXISTS vw_student_complaints;
DROP VIEW IF EXISTS vw_warden_summary;
DROP VIEW IF EXISTS vw_staff_performance;
DROP VIEW IF EXISTS vw_complaint_analytics;

DROP TRIGGER IF EXISTS trg_prevent_duplicate_active_complaint;
DROP TRIGGER IF EXISTS trg_verify_staff_availability;
DROP TRIGGER IF EXISTS trg_complaint_created_history;
DROP TRIGGER IF EXISTS trg_record_timestamps_before_update;
DROP TRIGGER IF EXISTS trg_complaint_status_notification;
DROP TRIGGER IF EXISTS trg_complaint_assigned_alert;

DROP PROCEDURE IF EXISTS sp_assign_complaint;
DROP PROCEDURE IF EXISTS sp_update_task_status;
DROP PROCEDURE IF EXISTS sp_resolve_complaint;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. TABLES & CONSTRAINTS
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

CREATE TABLE students (
    student_id INT PRIMARY KEY,
    roll_number VARCHAR(30) NOT NULL UNIQUE,
    hostel_block VARCHAR(20) NOT NULL,
    room_number VARCHAR(20) NOT NULL,
    FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT chk_room_number CHECK (CHAR_LENGTH(room_number) >= 1)
) ENGINE=InnoDB;

CREATE TABLE staff (
    staff_id INT PRIMARY KEY,
    specialization ENUM('Plumbing', 'Electrical', 'Carpentry', 'Cleaning', 'Internet/Wi-Fi', 'Appliance', 'General') NOT NULL,
    availability_status ENUM('Active', 'On Leave', 'Inactive') DEFAULT 'Active',
    FOREIGN KEY (staff_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

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

-- ---------------------------------------------------------------------
-- 2. TRIGGERS & DBMS ASSERTIONS
-- ---------------------------------------------------------------------
DELIMITER $$

CREATE TRIGGER trg_prevent_duplicate_active_complaint
BEFORE INSERT ON complaints
FOR EACH ROW
BEGIN
    DECLARE active_count INT DEFAULT 0;
    SELECT COUNT(*) INTO active_count
    FROM complaints
    WHERE student_id = NEW.student_id
      AND hostel_block = NEW.hostel_block
      AND room_number = NEW.room_number
      AND category = NEW.category
      AND status IN ('Pending', 'Assigned', 'In Progress');

    IF active_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'DBMS Assertion Violation: An active complaint already exists for this room and category. Please wait until it is resolved.';
    END IF;
END$$

CREATE TRIGGER trg_verify_staff_availability
BEFORE UPDATE ON complaints
FOR EACH ROW
BEGIN
    DECLARE staff_curr_status VARCHAR(20) DEFAULT NULL;
    IF NEW.assigned_staff_id IS NOT NULL AND (OLD.assigned_staff_id IS NULL OR OLD.assigned_staff_id <> NEW.assigned_staff_id) THEN
        SELECT availability_status INTO staff_curr_status
        FROM staff
        WHERE staff_id = NEW.assigned_staff_id;

        IF staff_curr_status IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'DBMS Assertion Violation: Assigned user is not a valid maintenance staff member.';
        ELSEIF staff_curr_status <> 'Active' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'DBMS Assertion Violation: Cannot assign task to staff member who is On Leave or Inactive.';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_complaint_created_history
AFTER INSERT ON complaints
FOR EACH ROW
BEGIN
    INSERT INTO complaint_history (
        complaint_id, old_status, new_status, changed_by_user_id, action_type, remarks, changed_at
    ) VALUES (
        NEW.complaint_id, NULL, NEW.status, NEW.student_id, 'Complaint Submitted',
        CONCAT('Initial complaint registered by student in Room ', NEW.room_number), NOW()
    );
END$$

CREATE TRIGGER trg_record_timestamps_before_update
BEFORE UPDATE ON complaints
FOR EACH ROW
BEGIN
    IF NEW.status = 'Assigned' AND (OLD.status IS NULL OR OLD.status = 'Pending') THEN
        IF NEW.assigned_at IS NULL THEN SET NEW.assigned_at = NOW(); END IF;
    END IF;

    IF NEW.status = 'Completed' AND OLD.status <> 'Completed' THEN
        IF NEW.completed_at IS NULL THEN SET NEW.completed_at = NOW(); END IF;
    END IF;

    IF NEW.status = 'Resolved' AND OLD.status <> 'Resolved' THEN
        IF NEW.resolved_at IS NULL THEN SET NEW.resolved_at = NOW(); END IF;
    END IF;
END$$

CREATE TRIGGER trg_complaint_status_notification
AFTER UPDATE ON complaints
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO complaint_history (
            complaint_id, old_status, new_status, changed_by_user_id, action_type, remarks, changed_at
        ) VALUES (
            NEW.complaint_id, OLD.status, NEW.status, COALESCE(NEW.assigned_staff_id, NEW.student_id),
            CONCAT('Status Changed to ', NEW.status),
            COALESCE(NEW.staff_notes, NEW.warden_notes, 'Status updated in workflow'), NOW()
        );

        INSERT INTO notifications (user_id, complaint_id, message, is_read, created_at)
        VALUES (
            NEW.student_id, NEW.complaint_id,
            CONCAT('Your complaint #', NEW.complaint_id, ' ("', NEW.title, '") status is now "', NEW.status, '".'),
            FALSE, NOW()
        );
    END IF;
END$$

CREATE TRIGGER trg_complaint_assigned_alert
AFTER UPDATE ON complaints
FOR EACH ROW
BEGIN
    IF NEW.assigned_staff_id IS NOT NULL AND (OLD.assigned_staff_id IS NULL OR OLD.assigned_staff_id <> NEW.assigned_staff_id) THEN
        INSERT INTO notifications (user_id, complaint_id, message, is_read, created_at)
        VALUES (
            NEW.assigned_staff_id, NEW.complaint_id,
            CONCAT('New Task: Complaint #', NEW.complaint_id, ' (', NEW.category, ') in Block ', NEW.hostel_block, ' Room ', NEW.room_number, ' has been assigned to you.'),
            FALSE, NOW()
        );
    END IF;
END$$

-- ---------------------------------------------------------------------
-- 3. STORED PROCEDURES (ACID TRANSACTIONS)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_assign_complaint (
    IN p_complaint_id INT,
    IN p_staff_id INT,
    IN p_warden_id INT,
    IN p_notes TEXT
)
BEGIN
    DECLARE v_curr_status VARCHAR(30);
    DECLARE v_staff_role VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT status INTO v_curr_status
    FROM complaints
    WHERE complaint_id = p_complaint_id
    FOR UPDATE;

    IF v_curr_status IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Complaint ID does not exist.';
    END IF;

    IF v_curr_status IN ('Resolved', 'Rejected') THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Cannot assign a complaint that is already Resolved or Rejected.';
    END IF;

    SELECT role INTO v_staff_role FROM users WHERE user_id = p_staff_id;
    IF v_staff_role IS NULL OR v_staff_role <> 'Staff' THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Selected assignee is not a valid maintenance staff user.';
    END IF;

    UPDATE complaints
    SET assigned_staff_id = p_staff_id,
        status = 'Assigned',
        assigned_at = NOW(),
        warden_notes = p_notes
    WHERE complaint_id = p_complaint_id;

    COMMIT;
END$$

CREATE PROCEDURE sp_update_task_status (
    IN p_complaint_id INT,
    IN p_staff_id INT,
    IN p_new_status VARCHAR(30),
    IN p_notes TEXT
)
BEGIN
    DECLARE v_assigned_to INT;
    DECLARE v_curr_status VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT assigned_staff_id, status INTO v_assigned_to, v_curr_status
    FROM complaints
    WHERE complaint_id = p_complaint_id
    FOR UPDATE;

    IF v_assigned_to IS NULL OR v_assigned_to <> p_staff_id THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Security Violation: Staff member can only update tasks assigned directly to them.';
    END IF;

    IF p_new_status NOT IN ('In Progress', 'Completed') THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Staff can only transition status to "In Progress" or "Completed".';
    END IF;

    UPDATE complaints
    SET status = p_new_status,
        staff_notes = p_notes
    WHERE complaint_id = p_complaint_id;

    COMMIT;
END$$

CREATE PROCEDURE sp_resolve_complaint (
    IN p_complaint_id INT,
    IN p_warden_id INT,
    IN p_notes TEXT
)
BEGIN
    DECLARE v_curr_status VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT status INTO v_curr_status
    FROM complaints
    WHERE complaint_id = p_complaint_id
    FOR UPDATE;

    IF v_curr_status IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Complaint ID does not exist.';
    END IF;

    UPDATE complaints
    SET status = 'Resolved',
        warden_notes = CONCAT(COALESCE(warden_notes, ''), ' [Warden Verification: ', p_notes, ']')
    WHERE complaint_id = p_complaint_id;

    COMMIT;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- 4. VIEWS
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_student_complaints AS
SELECT 
    c.complaint_id, c.title, c.category, c.hostel_block, c.room_number,
    c.description, c.priority, c.status, c.student_id,
    u_stu.full_name AS student_name, u_stu.email AS student_email, s.roll_number,
    c.assigned_staff_id, u_stf.full_name AS assigned_staff_name,
    stf.specialization AS staff_specialization, u_stf.phone AS staff_phone,
    c.warden_notes, c.staff_notes, c.complaint_date, c.assigned_at, c.completed_at, c.resolved_at
FROM complaints c
INNER JOIN users u_stu ON c.student_id = u_stu.user_id
INNER JOIN students s ON s.student_id = u_stu.user_id
LEFT JOIN users u_stf ON c.assigned_staff_id = u_stf.user_id
LEFT JOIN staff stf ON stf.staff_id = u_stf.user_id;

CREATE OR REPLACE VIEW vw_warden_summary AS
SELECT 
    hostel_block, category, COUNT(*) AS total_complaints,
    SUM(CASE WHEN status = 'Pending' THEN 1 ELSE 0 END) AS pending_count,
    SUM(CASE WHEN status = 'Assigned' THEN 1 ELSE 0 END) AS assigned_count,
    SUM(CASE WHEN status = 'In Progress' THEN 1 ELSE 0 END) AS in_progress_count,
    SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) AS completed_count,
    SUM(CASE WHEN status = 'Resolved' THEN 1 ELSE 0 END) AS resolved_count,
    SUM(CASE WHEN priority IN ('High', 'Urgent') AND status NOT IN ('Resolved', 'Rejected') THEN 1 ELSE 0 END) AS critical_unresolved_count
FROM complaints
GROUP BY hostel_block, category;

CREATE OR REPLACE VIEW vw_staff_performance AS
SELECT 
    stf.staff_id, u.full_name AS staff_name, stf.specialization, stf.availability_status,
    COUNT(c.complaint_id) AS total_assigned_tasks,
    SUM(CASE WHEN c.status = 'Assigned' THEN 1 ELSE 0 END) AS pending_tasks,
    SUM(CASE WHEN c.status = 'In Progress' THEN 1 ELSE 0 END) AS in_progress_tasks,
    SUM(CASE WHEN c.status = 'Completed' THEN 1 ELSE 0 END) AS completed_tasks,
    SUM(CASE WHEN c.status = 'Resolved' THEN 1 ELSE 0 END) AS resolved_tasks,
    SUM(CASE WHEN c.priority = 'Urgent' AND c.status NOT IN ('Resolved', 'Rejected') THEN 1 ELSE 0 END) AS urgent_tasks,
    SUM(CASE WHEN c.priority = 'High' AND c.status NOT IN ('Resolved', 'Rejected') THEN 1 ELSE 0 END) AS high_priority_tasks,
    SUM(CASE WHEN c.priority = 'Medium' AND c.status NOT IN ('Resolved', 'Rejected') THEN 1 ELSE 0 END) AS medium_priority_tasks,
    SUM(CASE WHEN c.priority = 'Low' AND c.status NOT IN ('Resolved', 'Rejected') THEN 1 ELSE 0 END) AS low_priority_tasks,
    ROUND(CASE WHEN COUNT(c.complaint_id) = 0 THEN 0.0 ELSE (SUM(CASE WHEN c.status IN ('Completed', 'Resolved') THEN 1 ELSE 0 END) * 100.0) / COUNT(c.complaint_id) END, 1) AS completion_rate_pct,
    ROUND(COALESCE(AVG(CASE WHEN c.completed_at IS NOT NULL AND c.assigned_at IS NOT NULL THEN TIMESTAMPDIFF(MINUTE, c.assigned_at, c.completed_at) / 60.0 ELSE NULL END), 0.0), 1) AS avg_resolution_hours
FROM staff stf
INNER JOIN users u ON stf.staff_id = u.user_id
LEFT JOIN complaints c ON c.assigned_staff_id = stf.staff_id
GROUP BY stf.staff_id, u.full_name, stf.specialization, stf.availability_status;

CREATE OR REPLACE VIEW vw_complaint_analytics AS
SELECT 
    category, COUNT(*) AS total_count,
    SUM(CASE WHEN status IN ('Completed', 'Resolved') THEN 1 ELSE 0 END) AS closed_count,
    SUM(CASE WHEN status NOT IN ('Completed', 'Resolved', 'Rejected') THEN 1 ELSE 0 END) AS open_count,
    ROUND((SUM(CASE WHEN status IN ('Completed', 'Resolved') THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 1) AS resolution_rate_pct,
    ROUND(COALESCE(AVG(CASE WHEN resolved_at IS NOT NULL THEN TIMESTAMPDIFF(MINUTE, complaint_date, resolved_at) / 60.0 ELSE NULL END), 0.0), 1) AS avg_total_cycle_hours
FROM complaints
GROUP BY category;

-- ---------------------------------------------------------------------
-- 5. SEED DATA (Exact 8 Users)
-- ---------------------------------------------------------------------
INSERT INTO users (user_id, username, password_hash, full_name, email, phone, role) VALUES
-- 3 Students
(1, 'medha', 'medha@1', 'Medha', 'medha@hostel.edu.in', '9876543210', 'Student'),
(2, 'nishmitha', 'nishmitha@2', 'Nishmitha', 'nishmitha@hostel.edu.in', '9876543211', 'Student'),
(3, 'akash', 'akash@3', 'Akash', 'akash@hostel.edu.in', '9876543212', 'Student'),

-- 2 Wardens
(4, 'rashmi', 'rashmi@01', 'Rashmi', 'rashmi@hostel.edu.in', '9988776655', 'Warden'),
(5, 'manohar', 'manohar@02', 'Manohar', 'manohar@hostel.edu.in', '9988776656', 'Warden'),

-- 3 Maintenance Staff
(6, 'manvith', 'manvith@01', 'Manvith', 'manvith@hostel.edu.in', '9123456780', 'Staff'),
(7, 'ramesh', 'ramesh@02', 'Ramesh', 'ramesh@hostel.edu.in', '9123456781', 'Staff'),
(8, 'sandhya', 'sandhya@03', 'Sandhya', 'sandhya@hostel.edu.in', '9123456782', 'Staff');

INSERT INTO students (student_id, roll_number, hostel_block, room_number) VALUES
(1, '4SF21IS026', 'A-Block', '101'),
(2, '4SF21IS030', 'A-Block', '205'),
(3, '4SF21IS005', 'B-Block', '312');

INSERT INTO staff (staff_id, specialization, availability_status) VALUES
(6, 'Plumbing', 'Active'),
(7, 'Electrical', 'Active'),
(8, 'Carpentry', 'Active');

INSERT INTO complaints (complaint_id, student_id, title, category, hostel_block, room_number, description, priority, status, assigned_staff_id, warden_notes, staff_notes, complaint_date, assigned_at, completed_at, resolved_at) VALUES
(1, 1, 'Bathroom tap leaking continuously', 'Plumbing', 'A-Block', '101', 'Water is dripping from the bathroom sink tap continuously, causing water wastage.', 'High', 'Pending', NULL, NULL, NULL, NOW() - INTERVAL 5 HOUR, NULL, NULL, NULL),
(2, 2, 'Ceiling fan making clicking sound and sparks', 'Electrical', 'A-Block', '205', 'Fan wobbles violently at speed 3 and produces intermittent clicking sounds.', 'Urgent', 'Assigned', 7, 'Please inspect regulator and blade alignment immediately.', NULL, NOW() - INTERVAL 1 DAY, NOW() - INTERVAL 20 HOUR, NULL, NULL),
(3, 1, 'Study desk drawer runner jammed', 'Carpentry', 'A-Block', '101', 'The bottom drawer of the study table cannot be pulled open. Wooden track seems misaligned.', 'Medium', 'In Progress', 8, 'Check track runner and replace screw if required.', 'Track inspected; replacement channel being installed.', NOW() - INTERVAL 2 DAY, NOW() - INTERVAL 1 DAY, NULL, NULL),
(4, 3, 'Water pipeline leakage under wash basin', 'Plumbing', 'B-Block', '312', 'Joint pipe fitting has loosened, water is pooling on the floor.', 'High', 'Completed', 6, 'Please fix joint connector and seal with Teflon tape.', 'Replaced sealing washer and tightened joint fitting.', NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 2 DAY, NOW() - INTERVAL 3 HOUR, NULL),
(5, 2, 'Tube light flickering in study area', 'Electrical', 'A-Block', '205', 'Electronic ballast buzzes and tube light flickers constantly.', 'Medium', 'Resolved', 7, 'Assigned to Ramesh. [Warden Verification: New LED batten installed and tested working fine.]', 'Replaced faulty ballast with new Philips LED batten.', NOW() - INTERVAL 4 DAY, NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 2 DAY, NOW() - INTERVAL 1 DAY);

ALTER TABLE complaints AUTO_INCREMENT = 6;
ALTER TABLE users AUTO_INCREMENT = 9;
