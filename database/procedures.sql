-- =====================================================================
-- HOSTEL MAINTENANCE AND COMPLAINT TRACKER
-- STORED PROCEDURES WITH ACID TRANSACTIONS
-- Engine: MySQL 8.0+
-- =====================================================================

USE hostel_tracker;

DROP PROCEDURE IF EXISTS sp_assign_complaint;
DROP PROCEDURE IF EXISTS sp_update_task_status;
DROP PROCEDURE IF EXISTS sp_resolve_complaint;

DELIMITER $$

-- ---------------------------------------------------------------------
-- PROCEDURE 1: sp_assign_complaint
-- Assigns a complaint to a technician with transaction integrity.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_assign_complaint (
    IN p_complaint_id INT,
    IN p_staff_id INT,
    IN p_warden_id INT,
    IN p_notes TEXT
)
proc_label: BEGIN
    DECLARE v_curr_status VARCHAR(30);
    DECLARE v_staff_role VARCHAR(20);

    -- Exception handler: rollback and re-raise on any SQL error
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Validate complaint existence and current status
    SELECT status INTO v_curr_status
    FROM complaints
    WHERE complaint_id = p_complaint_id
    FOR UPDATE;

    IF v_curr_status IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Complaint ID does not exist.';
    END IF;

    IF v_curr_status IN ('Resolved', 'Rejected') THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Cannot assign a complaint that is already Resolved or Rejected.';
    END IF;

    -- Validate that assigned staff exists and has Staff role
    SELECT role INTO v_staff_role
    FROM users
    WHERE user_id = p_staff_id;

    IF v_staff_role IS NULL OR v_staff_role <> 'Staff' THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Selected assignee is not a valid maintenance staff user.';
    END IF;

    -- Update complaint table (Triggers will fire automatically to check availability, set assigned_at, log history, and notify)
    UPDATE complaints
    SET assigned_staff_id = p_staff_id,
        status = 'Assigned',
        assigned_at = NOW(),
        warden_notes = p_notes
    WHERE complaint_id = p_complaint_id;

    COMMIT;
END$$

-- ---------------------------------------------------------------------
-- PROCEDURE 2: sp_update_task_status
-- Allows assigned staff technician to advance task status with checks.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_update_task_status (
    IN p_complaint_id INT,
    IN p_staff_id INT,
    IN p_new_status VARCHAR(30),
    IN p_notes TEXT
)
proc_label: BEGIN
    DECLARE v_assigned_to INT;
    DECLARE v_curr_status VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Lock and verify complaint ownership
    SELECT assigned_staff_id, status INTO v_assigned_to, v_curr_status
    FROM complaints
    WHERE complaint_id = p_complaint_id
    FOR UPDATE;

    IF v_assigned_to IS NULL OR v_assigned_to <> p_staff_id THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Security Violation: Staff member can only update tasks assigned directly to them.';
    END IF;

    IF p_new_status NOT IN ('In Progress', 'Completed') THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Staff can only transition status to "In Progress" or "Completed".';
    END IF;

    -- Update complaint
    UPDATE complaints
    SET status = p_new_status,
        staff_notes = p_notes
    WHERE complaint_id = p_complaint_id;

    COMMIT;
END$$

-- ---------------------------------------------------------------------
-- PROCEDURE 3: sp_resolve_complaint
-- Warden verifies completion and marks complaint officially Resolved.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_resolve_complaint (
    IN p_complaint_id INT,
    IN p_warden_id INT,
    IN p_notes TEXT
)
proc_label: BEGIN
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
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Complaint ID does not exist.';
    END IF;

    -- Update status to Resolved (Trigger will stamp resolved_at and notify student)
    UPDATE complaints
    SET status = 'Resolved',
        warden_notes = CONCAT(COALESCE(warden_notes, ''), ' [Warden Verification: ', p_notes, ']')
    WHERE complaint_id = p_complaint_id;

    COMMIT;
END$$

DELIMITER ;
