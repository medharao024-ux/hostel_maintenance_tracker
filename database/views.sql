-- =====================================================================
-- HOSTEL MAINTENANCE AND COMPLAINT TRACKER
-- DATABASE VIEWS FOR REPORTING & REAL-TIME DASHBOARDS
-- Engine: MySQL 8.0+
-- =====================================================================

USE hostel_tracker;

-- ---------------------------------------------------------------------
-- VIEW 1: vw_student_complaints
-- Complete view of complaints with student and assigned staff details
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_student_complaints AS
SELECT 
    c.complaint_id,
    c.title,
    c.category,
    c.hostel_block,
    c.room_number,
    c.description,
    c.priority,
    c.status,
    c.student_id,
    u_stu.full_name AS student_name,
    u_stu.email AS student_email,
    s.roll_number,
    c.assigned_staff_id,
    u_stf.full_name AS assigned_staff_name,
    stf.specialization AS staff_specialization,
    u_stf.phone AS staff_phone,
    c.warden_notes,
    c.staff_notes,
    c.complaint_date,
    c.assigned_at,
    c.completed_at,
    c.resolved_at
FROM complaints c
INNER JOIN users u_stu ON c.student_id = u_stu.user_id
INNER JOIN students s ON s.student_id = u_stu.user_id
LEFT JOIN users u_stf ON c.assigned_staff_id = u_stf.user_id
LEFT JOIN staff stf ON stf.staff_id = u_stf.user_id;

-- ---------------------------------------------------------------------
-- VIEW 2: vw_warden_summary
-- Aggregated operational overview grouped by hostel block & category
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_warden_summary AS
SELECT 
    hostel_block,
    category,
    COUNT(*) AS total_complaints,
    SUM(CASE WHEN status = 'Pending' THEN 1 ELSE 0 END) AS pending_count,
    SUM(CASE WHEN status = 'Assigned' THEN 1 ELSE 0 END) AS assigned_count,
    SUM(CASE WHEN status = 'In Progress' THEN 1 ELSE 0 END) AS in_progress_count,
    SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) AS completed_count,
    SUM(CASE WHEN status = 'Resolved' THEN 1 ELSE 0 END) AS resolved_count,
    SUM(CASE WHEN priority IN ('High', 'Urgent') AND status NOT IN ('Resolved', 'Rejected') THEN 1 ELSE 0 END) AS critical_unresolved_count
FROM complaints
GROUP BY hostel_block, category;

-- ---------------------------------------------------------------------
-- VIEW 3: vw_staff_performance
-- Detailed work and performance analytics for each maintenance staff
-- Matches requirements:
-- - Assigned Tasks
-- - Pending Tasks
-- - In Progress
-- - Completed Tasks
-- - Priority Analysis
-- - Completion Rate
-- - Average Resolution Time
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_staff_performance AS
SELECT 
    stf.staff_id,
    u.full_name AS staff_name,
    stf.specialization,
    stf.availability_status,
    COUNT(c.complaint_id) AS total_assigned_tasks,
    SUM(CASE WHEN c.status = 'Assigned' THEN 1 ELSE 0 END) AS pending_tasks,
    SUM(CASE WHEN c.status = 'In Progress' THEN 1 ELSE 0 END) AS in_progress_tasks,
    SUM(CASE WHEN c.status = 'Completed' THEN 1 ELSE 0 END) AS completed_tasks,
    SUM(CASE WHEN c.status = 'Resolved' THEN 1 ELSE 0 END) AS resolved_tasks,
    SUM(CASE WHEN c.priority = 'Urgent' AND c.status NOT IN ('Resolved', 'Rejected') THEN 1 ELSE 0 END) AS urgent_tasks,
    SUM(CASE WHEN c.priority = 'High' AND c.status NOT IN ('Resolved', 'Rejected') THEN 1 ELSE 0 END) AS high_priority_tasks,
    SUM(CASE WHEN c.priority = 'Medium' AND c.status NOT IN ('Resolved', 'Rejected') THEN 1 ELSE 0 END) AS medium_priority_tasks,
    SUM(CASE WHEN c.priority = 'Low' AND c.status NOT IN ('Resolved', 'Rejected') THEN 1 ELSE 0 END) AS low_priority_tasks,
    ROUND(
        CASE 
            WHEN COUNT(c.complaint_id) = 0 THEN 0.0 
            ELSE (SUM(CASE WHEN c.status IN ('Completed', 'Resolved') THEN 1 ELSE 0 END) * 100.0) / COUNT(c.complaint_id) 
        END, 
        1
    ) AS completion_rate_pct,
    ROUND(
        COALESCE(
            AVG(
                CASE 
                    WHEN c.completed_at IS NOT NULL AND c.assigned_at IS NOT NULL 
                    THEN TIMESTAMPDIFF(MINUTE, c.assigned_at, c.completed_at) / 60.0 
                    ELSE NULL 
                END
            ), 
            0.0
        ), 
        1
    ) AS avg_resolution_hours
FROM staff stf
INNER JOIN users u ON stf.staff_id = u.user_id
LEFT JOIN complaints c ON c.assigned_staff_id = stf.staff_id
GROUP BY stf.staff_id, u.full_name, stf.specialization, stf.availability_status;

-- ---------------------------------------------------------------------
-- VIEW 4: vw_category_analytics
-- Category-wise distribution and overall resolution metrics for Warden
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_complaint_analytics AS
SELECT 
    category,
    COUNT(*) AS total_count,
    SUM(CASE WHEN status IN ('Completed', 'Resolved') THEN 1 ELSE 0 END) AS closed_count,
    SUM(CASE WHEN status NOT IN ('Completed', 'Resolved', 'Rejected') THEN 1 ELSE 0 END) AS open_count,
    ROUND(
        (SUM(CASE WHEN status IN ('Completed', 'Resolved') THEN 1 ELSE 0 END) * 100.0) / COUNT(*),
        1
    ) AS resolution_rate_pct,
    ROUND(
        COALESCE(
            AVG(
                CASE 
                    WHEN resolved_at IS NOT NULL 
                    THEN TIMESTAMPDIFF(MINUTE, complaint_date, resolved_at) / 60.0 
                    ELSE NULL 
                END
            ), 
            0.0
        ), 
        1
    ) AS avg_total_cycle_hours
FROM complaints
GROUP BY category;
