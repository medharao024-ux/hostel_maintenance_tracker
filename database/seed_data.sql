-- =====================================================================
-- HOSTEL MAINTENANCE AND COMPLAINT TRACKER
-- EXACT USER CREDENTIALS SEED DATA (DML)
-- 3 Students, 2 Wardens, 3 Maintenance Staff
-- =====================================================================

USE hostel_tracker;

SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE notifications;
TRUNCATE TABLE complaint_history;
TRUNCATE TABLE complaints;
TRUNCATE TABLE staff;
TRUNCATE TABLE students;
TRUNCATE TABLE users;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. USERS TABLE (Exactly 8 Users)
-- Emails: name@hostel.edu.in
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

-- ---------------------------------------------------------------------
-- 2. STUDENTS PROFILE
-- ---------------------------------------------------------------------
INSERT INTO students (student_id, roll_number, hostel_block, room_number) VALUES
(1, '4SF21IS026', 'A-Block', '101'),
(2, '4SF21IS030', 'A-Block', '205'),
(3, '4SF21IS005', 'B-Block', '312');

-- ---------------------------------------------------------------------
-- 3. STAFF PROFILE
-- ---------------------------------------------------------------------
INSERT INTO staff (staff_id, specialization, availability_status) VALUES
(6, 'Plumbing', 'Active'),
(7, 'Electrical', 'Active'),
(8, 'Cleaning', 'Active');

-- ---------------------------------------------------------------------
-- 4. INITIAL COMPLAINTS
-- ---------------------------------------------------------------------
INSERT INTO complaints (complaint_id, student_id, title, category, hostel_block, room_number, description, priority, status, assigned_staff_id, warden_notes, staff_notes, complaint_date, assigned_at, completed_at, resolved_at) VALUES
(1, 1, 'Bathroom tap leaking continuously', 'Plumbing', 'A-Block', '101', 'Water is dripping from the bathroom sink tap continuously, causing water wastage and noise.', 'High', 'Pending', NULL, NULL, NULL, NOW() - INTERVAL 5 HOUR, NULL, NULL, NULL),
(2, 2, 'Ceiling fan making clicking sound and sparks', 'Electrical', 'A-Block', '205', 'Fan wobbles violently at speed 3 and produces intermittent clicking sounds.', 'Urgent', 'Assigned', 7, 'Please inspect regulator and blade alignment immediately.', NULL, NOW() - INTERVAL 1 DAY, NOW() - INTERVAL 20 HOUR, NULL, NULL),
(3, 1, 'Study desk drawer runner jammed', 'Carpentry', 'A-Block', '101', 'The bottom drawer of the study table cannot be pulled open. Wooden track seems misaligned.', 'Medium', 'In Progress', 8, 'Check track runner and replace screw if required.', 'Track inspected; replacement channel being installed.', NOW() - INTERVAL 2 DAY, NOW() - INTERVAL 1 DAY, NULL, NULL),
(4, 3, 'Water pipeline leakage under wash basin', 'Plumbing', 'B-Block', '312', 'Joint pipe fitting has loosened, water is pooling on the floor.', 'High', 'Completed', 6, 'Please fix joint connector and seal with Teflon tape.', 'Replaced sealing washer and tightened joint fitting.', NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 2 DAY, NOW() - INTERVAL 3 HOUR, NULL),
(5, 2, 'Tube light flickering in study area', 'Electrical', 'A-Block', '205', 'Electronic ballast buzzes and tube light flickers constantly.', 'Medium', 'Resolved', 7, 'Assigned to Ramesh. [Warden Verification: New LED batten installed and tested working fine.]', 'Replaced faulty ballast with new Philips LED batten.', NOW() - INTERVAL 4 DAY, NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 2 DAY, NOW() - INTERVAL 1 DAY);

ALTER TABLE complaints AUTO_INCREMENT = 6;
ALTER TABLE users AUTO_INCREMENT = 9;
