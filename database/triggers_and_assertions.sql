-- =====================================================================
-- HOSTEL MAINTENANCE AND COMPLAINT TRACKER
-- TRIGGERS AND DBMS BUSINESS ASSERTIONS
-- Engine: MySQL 8.0+
-- =====================================================================

USE hostel_tracker;

DROP TRIGGER IF EXISTS trg_prevent_duplicate_active_complaint;
DROP TRIGGER IF EXISTS trg_verify_staff_availability;
DROP TRIGGER IF EXISTS trg_complaint_created_history;
DROP TRIGGER IF EXISTS trg_record_timestamps_before_update;
DROP TRIGGER IF EXISTS trg_complaint_status_notification;
DROP TRIGGER IF EXISTS trg_complaint_assigned_alert;

DELIMITER $$

-- ---------------------------------------------------------------------
-- ASSERTION 1: Prevent Duplicate Active Complaints
-- Enforces DBMS invariant: A student cannot submit a new complaint
-- for the identical block, room, and category if a complaint is
-- currently Pending, Assigned, or In Progress.
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- ASSERTION 2: Verify Staff Availability On Assignment
-- Enforces DBMS invariant: Complaints can only be assigned to staff
-- who are registered in the staff table with status 'Active'.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_verify_staff_availability
BEFORE UPDATE ON complaints
FOR EACH ROW
BEGIN
    DECLARE staff_curr_status VARCHAR(20) DEFAULT NULL;

    -- Only check if assigned_staff_id is being newly set or changed
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

-- ---------------------------------------------------------------------
-- TRIGGER 3: Audit Log and Warden Notification on Complaint Creation
-- Automatically creates an initial audit log entry upon submission
-- and sends an automated notification alert to all Wardens.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_complaint_created_history
AFTER INSERT ON complaints
FOR EACH ROW
BEGIN
    -- 1. Insert audit log in complaint_history
    INSERT INTO complaint_history (
        complaint_id,
        old_status,
        new_status,
        changed_by_user_id,
        action_type,
        remarks,
        changed_at
    ) VALUES (
        NEW.complaint_id,
        NULL,
        NEW.status,
        NEW.student_id,
        'Complaint Submitted',
        CONCAT('Initial complaint registered by student in Room ', NEW.room_number),
        NOW()
    );

    -- 2. Send automated notification to all Wardens
    INSERT INTO notifications (
        user_id,
        complaint_id,
        message,
        is_read,
        created_at
    )
    SELECT u.user_id, NEW.complaint_id,
           CONCAT('New Complaint #', NEW.complaint_id, ' filed by student in Room ', NEW.room_number, ' (', NEW.category, ' - ', NEW.priority, ' priority): "', NEW.title, '"'),
           FALSE, NOW()
    FROM users u
    WHERE u.role = 'Warden';
END$$

-- ---------------------------------------------------------------------
-- TRIGGER 4: Automatically Stamp Timestamps on State Transition
-- Sets assigned_at, completed_at, and resolved_at dynamically.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_record_timestamps_before_update
BEFORE UPDATE ON complaints
FOR EACH ROW
BEGIN
    -- Assigned timestamp
    IF NEW.status = 'Assigned' AND (OLD.status IS NULL OR OLD.status = 'Pending') THEN
        IF NEW.assigned_at IS NULL THEN
            SET NEW.assigned_at = NOW();
        END IF;
    END IF;

    -- Completed timestamp
    IF NEW.status = 'Completed' AND OLD.status <> 'Completed' THEN
        IF NEW.completed_at IS NULL THEN
            SET NEW.completed_at = NOW();
        END IF;
    END IF;

    -- Resolved timestamp
    IF NEW.status = 'Resolved' AND OLD.status <> 'Resolved' THEN
        IF NEW.resolved_at IS NULL THEN
            SET NEW.resolved_at = NOW();
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER 5: Status Change Notifications (Student & Warden) and Audit History
-- Automatically inserts notifications for student & warden, and records history.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_complaint_status_notification
AFTER UPDATE ON complaints
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        -- 1. Insert audit log in complaint_history
        INSERT INTO complaint_history (
            complaint_id,
            old_status,
            new_status,
            changed_by_user_id,
            action_type,
            remarks,
            changed_at
        ) VALUES (
            NEW.complaint_id,
            OLD.status,
            NEW.status,
            COALESCE(NEW.assigned_staff_id, NEW.student_id),
            CONCAT('Status Changed to ', NEW.status),
            COALESCE(NEW.staff_notes, NEW.warden_notes, 'Status updated in workflow'),
            NOW()
        );

        -- 2. Send automated notification to Student
        INSERT INTO notifications (
            user_id,
            complaint_id,
            message,
            is_read,
            created_at
        ) VALUES (
            NEW.student_id,
            NEW.complaint_id,
            CONCAT('Your complaint #', NEW.complaint_id, ' ("', NEW.title, '") status is now "', NEW.status, '".'),
            FALSE,
            NOW()
        );

        -- 3. If staff updated status to 'In Progress' or 'Completed', notify all Wardens
        IF NEW.status IN ('In Progress', 'Completed') THEN
            INSERT INTO notifications (
                user_id,
                complaint_id,
                message,
                is_read,
                created_at
            )
            SELECT u.user_id, NEW.complaint_id,
                   CONCAT('Staff update on Complaint #', NEW.complaint_id, ' (Room ', NEW.room_number, '): Status changed to "', NEW.status, '".'),
                   FALSE, NOW()
            FROM users u
            WHERE u.role = 'Warden';
        END IF;

        -- 4. If complaint is Resolved by Warden, notify student
        IF NEW.status = 'Resolved' THEN
            INSERT INTO notifications (
                user_id,
                complaint_id,
                message,
                is_read,
                created_at
            ) VALUES (
                NEW.student_id,
                NEW.complaint_id,
                CONCAT('Complaint #', NEW.complaint_id, ' has been verified and marked RESOLVED by Warden. Thank you for your patience!'),
                FALSE,
                NOW()
            );
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER 6: Staff Assignment Alert
-- Automatically notifies the assigned staff technician.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_complaint_assigned_alert
AFTER UPDATE ON complaints
FOR EACH ROW
BEGIN
    IF NEW.assigned_staff_id IS NOT NULL AND (OLD.assigned_staff_id IS NULL OR OLD.assigned_staff_id <> NEW.assigned_staff_id) THEN
        INSERT INTO notifications (
            user_id,
            complaint_id,
            message,
            is_read,
            created_at
        ) VALUES (
            NEW.assigned_staff_id,
            NEW.complaint_id,
            CONCAT('New Task: Complaint #', NEW.complaint_id, ' (', NEW.category, ') in Block ', NEW.hostel_block, ' Room ', NEW.room_number, ' has been assigned to you.'),
            FALSE,
            NOW()
        );
    END IF;
END$$

DELIMITER ;
