-- =====================================================================
-- HOSTEL MAINTENANCE AND COMPLAINT TRACKER
-- COLLEGE DBMS EVALUATION & VIVA QUERIES DEMONSTRATION
-- Engine: MySQL 8.0+
-- This script contains all theoretical & practical SQL demonstrations
-- required for your lab evaluation, project viva, and report.
-- =====================================================================

USE hostel_tracker;

-- =====================================================================
-- SECTION 1: JOINS DEMONSTRATION
-- =====================================================================

-- 1.1 INNER JOIN: Get active complaints along with Student Details
SELECT 
    c.complaint_id,
    c.title,
    c.category,
    s.roll_number,
    u.full_name AS student_name,
    c.hostel_block,
    c.room_number,
    c.status
FROM complaints c
INNER JOIN users u ON c.student_id = u.user_id
INNER JOIN students s ON s.student_id = u.user_id
WHERE c.status NOT IN ('Resolved', 'Rejected');

-- 1.2 LEFT OUTER JOIN: View all complaints, including those not yet assigned to any staff
SELECT 
    c.complaint_id,
    c.title,
    c.status,
    c.priority,
    COALESCE(u_staff.full_name, 'UNASSIGNED') AS assigned_technician,
    COALESCE(stf.specialization, 'N/A') AS specialization
FROM complaints c
LEFT JOIN users u_staff ON c.assigned_staff_id = u_staff.user_id
LEFT JOIN staff stf ON stf.staff_id = u_staff.user_id;

-- 1.3 MULTI-TABLE JOIN: Detailed workflow tracking with audit trail
SELECT 
    c.complaint_id,
    c.title,
    h.old_status,
    h.new_status,
    h.action_type,
    u_actor.full_name AS action_taken_by,
    h.remarks,
    h.changed_at
FROM complaint_history h
INNER JOIN complaints c ON h.complaint_id = c.complaint_id
LEFT JOIN users u_actor ON h.changed_by_user_id = u_actor.user_id
ORDER BY h.changed_at DESC;


-- =====================================================================
-- SECTION 2: AGGREGATE QUERIES & GROUP BY / HAVING
-- =====================================================================

-- 2.1 Category Breakdown with Total & Unresolved Counts
SELECT 
    category,
    COUNT(*) AS total_filed,
    SUM(CASE WHEN status IN ('Pending', 'Assigned', 'In Progress') THEN 1 ELSE 0 END) AS active_open,
    SUM(CASE WHEN status = 'Resolved' THEN 1 ELSE 0 END) AS resolved_count
FROM complaints
GROUP BY category
ORDER BY total_filed DESC;

-- 2.2 HAVING Clause: Find hostel blocks with more than 1 active complaint
SELECT 
    hostel_block,
    COUNT(*) AS active_complaints_count
FROM complaints
WHERE status NOT IN ('Resolved', 'Rejected')
GROUP BY hostel_block
HAVING COUNT(*) >= 1;

-- 2.3 Performance Metrics: Average resolution time (hours) per staff member
SELECT 
    u.full_name AS staff_name,
    stf.specialization,
    COUNT(c.complaint_id) AS total_handled,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, c.assigned_at, c.completed_at) / 60.0), 2) AS avg_resolution_hours
FROM staff stf
INNER JOIN users u ON stf.staff_id = u.user_id
INNER JOIN complaints c ON c.assigned_staff_id = stf.staff_id
WHERE c.completed_at IS NOT NULL
GROUP BY u.full_name, stf.specialization;


-- =====================================================================
-- SECTION 3: NESTED SUBQUERIES (IN, EXISTS, CORRELATED)
-- =====================================================================

-- 3.1 Subquery with IN: Students who filed High or Urgent priority complaints
SELECT 
    u.full_name,
    s.roll_number,
    s.hostel_block,
    s.room_number
FROM students s
INNER JOIN users u ON s.student_id = u.user_id
WHERE s.student_id IN (
    SELECT DISTINCT student_id
    FROM complaints
    WHERE priority IN ('High', 'Urgent')
);

-- 3.2 Correlated Subquery with EXISTS: Maintenance staff currently working on an active task
SELECT 
    u.full_name AS busy_staff_name,
    stf.specialization
FROM staff stf
INNER JOIN users u ON stf.staff_id = u.user_id
WHERE EXISTS (
    SELECT 1 
    FROM complaints c
    WHERE c.assigned_staff_id = stf.staff_id
      AND c.status = 'In Progress'
);

-- 3.3 Scalar Subquery: Complaints that took longer to resolve than the overall hostel average
SELECT 
    complaint_id,
    title,
    ROUND(TIMESTAMPDIFF(MINUTE, assigned_at, completed_at) / 60.0, 2) AS resolution_time_hrs
FROM complaints
WHERE completed_at IS NOT NULL
  AND TIMESTAMPDIFF(MINUTE, assigned_at, completed_at) > (
      SELECT AVG(TIMESTAMPDIFF(MINUTE, assigned_at, completed_at))
      FROM complaints
      WHERE completed_at IS NOT NULL
  );


-- =====================================================================
-- SECTION 4: QUERYING DBMS ANALYTICAL VIEWS
-- =====================================================================

-- 4.1 Query View: Student Complaints Master View
SELECT * FROM vw_student_complaints WHERE student_id = 1;

-- 4.2 Query View: Warden Block & Category Operational Matrix
SELECT * FROM vw_warden_summary;

-- 4.3 Query View: Staff Work & KPI Performance Analysis
-- (Directly satisfies staff dashboard evaluation)
SELECT 
    staff_name,
    specialization,
    total_assigned_tasks,
    pending_tasks,
    in_progress_tasks,
    completed_tasks,
    completion_rate_pct,
    avg_resolution_hours
FROM vw_staff_performance;

-- 4.4 Query View: High-level Complaint Analytics
SELECT * FROM vw_complaint_analytics;


-- =====================================================================
-- SECTION 5: DBMS ASSERTIONS DEMONSTRATION (Error Handling & Constraints)
-- =====================================================================

-- 5.1 TEST ASSERTION 1: Prevent duplicate active complaint
-- EXPECTED: Fails with SQLSTATE '45000' because Complaint #1 for A-Block Room 101 Plumbing is already Pending!
-- Uncomment to execute test:
/*
INSERT INTO complaints (student_id, title, category, hostel_block, room_number, description, priority, status)
VALUES (1, 'Second leakage reported', 'Plumbing', 'A-Block', '101', 'Tap dripping again', 'Medium', 'Pending');
*/

-- 5.2 TEST ASSERTION 2: Prevent assignment to staff who is 'On Leave'
-- EXPECTED: Fails with SQLSTATE '45000' because staff_id=9 (Vikram Singh) has availability_status = 'On Leave'!
-- Uncomment to execute test:
/*
UPDATE complaints
SET assigned_staff_id = 9
WHERE complaint_id = 1;
*/


-- =====================================================================
-- SECTION 6: STORED PROCEDURES & ACID TRANSACTIONS DEMONSTRATION
-- =====================================================================

-- 6.1 Call sp_assign_complaint: Warden assigns Complaint #1 to Plumber Suresh (staff_id=5)
CALL sp_assign_complaint(1, 5, 4, 'Please inspect washers and pipe joints immediately.');

-- Verify the result of procedure call:
SELECT complaint_id, status, assigned_staff_id, assigned_at, warden_notes 
FROM complaints WHERE complaint_id = 1;

-- 6.2 Call sp_update_task_status: Plumber Suresh moves complaint to 'In Progress'
CALL sp_update_task_status(1, 5, 'In Progress', 'Inspected tap: ordering replacement ceramic cartridge.');

-- Verify status changed and trigger logged history:
SELECT * FROM complaint_history WHERE complaint_id = 1 ORDER BY history_id DESC LIMIT 2;

-- 6.3 Verify Notifications generated by Triggers
SELECT n.notification_id, u.full_name AS recipient, n.message, n.created_at
FROM notifications n
INNER JOIN users u ON n.user_id = u.user_id
WHERE n.complaint_id = 1;
