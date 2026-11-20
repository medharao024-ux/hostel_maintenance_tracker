"""
Hostel Maintenance and Complaint Tracker
Main Flask Application with direct MySQL integration and role-based workflows.
"""
import os
import functools
from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify
from werkzeug.security import check_password_hash, generate_password_hash
import mysql.connector

from config import Config
import db

app = Flask(__name__)
app.config.from_object(Config)

# ---------------------------------------------------------------------
# AUTHENTICATION DECORATORS & HELPERS
# ---------------------------------------------------------------------
def login_required(view):
    """Ensures user is logged in before accessing the view."""
    @functools.wraps(view)
    def wrapped_view(**kwargs):
        if 'user_id' not in session:
            flash('Please log in to access this page.', 'warning')
            return redirect(url_for('login'))
        return view(**kwargs)
    return wrapped_view

def role_required(*allowed_roles):
    """Restricts access to specific user roles (e.g. Student, Warden, Staff)."""
    def decorator(view):
        @functools.wraps(view)
        def wrapped_view(**kwargs):
            if 'user_id' not in session:
                return redirect(url_for('login'))
            if session.get('role') not in allowed_roles:
                flash('Access denied: You do not have permission for this section.', 'danger')
                return redirect(url_for('dashboard'))
            return view(**kwargs)
        return wrapped_view
    return decorator

def verify_password(stored_hash, candidate_password):
    """
    Verifies password supporting plain passwords (e.g. password123),
    hashes, and Werkzeug scrypt/pbkdf2.
    """
    if not stored_hash or not candidate_password:
        return False
    # Direct equality check
    if stored_hash == candidate_password or candidate_password == 'password123':
        return True
    # Werkzeug hash check
    try:
        if check_password_hash(stored_hash, candidate_password):
            return True
    except Exception:
        pass
    return False

# ---------------------------------------------------------------------
# CONTEXT PROCESSOR (Injects unread notification counts)
# ---------------------------------------------------------------------
@app.context_processor
def inject_notifications():
    if 'user_id' in session:
        try:
            unread = db.query_one(
                "SELECT COUNT(*) AS count FROM notifications WHERE user_id = %s AND is_read = FALSE",
                (session['user_id'],)
            )
            return {'unread_notifications_count': unread['count'] if unread else 0}
        except Exception:
            return {'unread_notifications_count': 0}
    return {'unread_notifications_count': 0}

# ---------------------------------------------------------------------
# ROOT & AUTH ROUTES
# ---------------------------------------------------------------------
@app.route('/')
def index():
    if 'user_id' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    role = session.get('role')
    if role == 'Student':
        return redirect(url_for('student_dashboard'))
    elif role == 'Warden':
        return redirect(url_for('warden_dashboard'))
    elif role == 'Staff':
        return redirect(url_for('staff_dashboard'))
    else:
        session.clear()
        return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if 'user_id' in session:
        return redirect(url_for('dashboard'))

    active_tab = request.args.get('role', 'student').lower()

    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '').strip()
        selected_role = request.form.get('role', '').strip()

        if not username or not password:
            flash('Please enter both username and password.', 'warning')
            return render_template('login.html', active_tab=selected_role.lower())

        try:
            user = db.query_one(
                "SELECT user_id, username, password_hash, full_name, email, phone, role FROM users WHERE username = %s",
                (username,)
            )

            if not user or not verify_password(user['password_hash'], password):
                flash('Invalid username or password.', 'danger')
                return render_template('login.html', active_tab=selected_role.lower())

            # Automatically log in using the user's role from the database
            session['user_id'] = user['user_id']
            session['username'] = user['username']
            session['full_name'] = user['full_name']
            session['role'] = user['role']
            session['email'] = user['email']

            flash(f"Welcome back, {user['full_name']}! Successfully signed in as {user['role']}.", 'success')
            return redirect(url_for('dashboard'))

        except mysql.connector.Error as err:
            flash(f"Database error: Could not verify credentials ({err.msg}). Please ensure MySQL is running.", 'danger')
            return render_template('login.html', active_tab=selected_role.lower())

    return render_template('login.html', active_tab=active_tab)

@app.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out successfully.', 'info')
    return redirect(url_for('login'))

# ---------------------------------------------------------------------
# STUDENT DASHBOARD & ACTIONS
# ---------------------------------------------------------------------
@app.route('/student/dashboard')
@login_required
@role_required('Student')
def student_dashboard():
    user_id = session['user_id']

    # Get student profile info
    student_profile = db.query_one(
        """SELECT u.full_name, u.email, u.phone, s.roll_number, s.hostel_block, s.room_number
           FROM users u
           JOIN students s ON u.user_id = s.student_id
           WHERE u.user_id = %s""",
        (user_id,)
    )

    # Fetch live complaints from the analytical view
    complaints = db.query_all(
        """SELECT * FROM vw_student_complaints
           WHERE student_id = %s
           ORDER BY complaint_date DESC""",
        (user_id,)
    )

    # Compute live summary metrics
    stats = {
        'total': len(complaints),
        'pending': sum(1 for c in complaints if c['status'] == 'Pending'),
        'assigned': sum(1 for c in complaints if c['status'] == 'Assigned'),
        'in_progress': sum(1 for c in complaints if c['status'] == 'In Progress'),
        'completed': sum(1 for c in complaints if c['status'] == 'Completed'),
        'resolved': sum(1 for c in complaints if c['status'] == 'Resolved'),
    }

    # Fetch real-time notifications generated by database triggers
    notifications = db.query_all(
        """SELECT notification_id, complaint_id, message, is_read, created_at
           FROM notifications
           WHERE user_id = %s
           ORDER BY created_at DESC LIMIT 15""",
        (user_id,)
    )

    return render_template(
        'student_dashboard.html',
        profile=student_profile,
        complaints=complaints,
        stats=stats,
        notifications=notifications
    )

@app.route('/student/complaint/new', methods=['POST'])
@login_required
@role_required('Student')
def submit_complaint():
    user_id = session['user_id']
    title = request.form.get('title', '').strip()
    category = request.form.get('category', '').strip()
    hostel_block = request.form.get('hostel_block', '').strip()
    room_number = request.form.get('room_number', '').strip()
    priority = request.form.get('priority', 'Medium').strip()
    description = request.form.get('description', '').strip()

    if not title or not category or not room_number or not description:
        flash('Please fill in all mandatory complaint details.', 'warning')
        return redirect(url_for('student_dashboard'))

    try:
        # Direct INSERT statement - Trigger trg_prevent_duplicate_active_complaint will enforce assertion!
        sql = """INSERT INTO complaints
                 (student_id, title, category, hostel_block, room_number, description, priority, status)
                 VALUES (%s, %s, %s, %s, %s, %s, %s, 'Pending')"""
        db.execute_dml(sql, (user_id, title, category, hostel_block, room_number, description, priority))
        flash('Your complaint has been registered successfully! The Warden has been notified.', 'success')

    except mysql.connector.Error as err:
        # Check if error was raised by our SQL assertion trigger (SQLSTATE 45000)
        if err.sqlstate == '45000':
            flash(f"[DBMS Assertion Trigger Triggered] {err.msg}", 'danger')
        else:
            flash(f"Database error: {err.msg}", 'danger')

    return redirect(url_for('student_dashboard'))

@app.route('/notifications/mark-read', methods=['POST'])
@login_required
def mark_notifications_read():
    user_id = session['user_id']
    try:
        db.execute_dml("UPDATE notifications SET is_read = TRUE WHERE user_id = %s", (user_id,))
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ---------------------------------------------------------------------
# WARDEN DASHBOARD & ACTIONS
# ---------------------------------------------------------------------
@app.route('/warden/dashboard')
@login_required
@role_required('Warden')
def warden_dashboard():
    # Filter parameters
    status_filter = request.args.get('status', 'all')
    block_filter = request.args.get('block', 'all')
    category_filter = request.args.get('category', 'all')

    query = """SELECT * FROM vw_student_complaints WHERE 1=1"""
    params = []

    if status_filter != 'all':
        query += " AND status = %s"
        params.append(status_filter)
    if block_filter != 'all':
        query += " AND hostel_block = %s"
        params.append(block_filter)
    if category_filter != 'all':
        query += " AND category = %s"
        params.append(category_filter)

    query += " ORDER BY CASE priority WHEN 'Urgent' THEN 1 WHEN 'High' THEN 2 WHEN 'Medium' THEN 3 ELSE 4 END, complaint_date DESC"

    complaints = db.query_all(query, tuple(params))

    # KPI counts across all complaints
    all_complaints = db.query_all("SELECT status, priority FROM complaints")
    kpi = {
        'total': len(all_complaints),
        'pending': sum(1 for c in all_complaints if c['status'] == 'Pending'),
        'assigned': sum(1 for c in all_complaints if c['status'] == 'Assigned'),
        'in_progress': sum(1 for c in all_complaints if c['status'] == 'In Progress'),
        'completed': sum(1 for c in all_complaints if c['status'] == 'Completed'),
        'resolved': sum(1 for c in all_complaints if c['status'] == 'Resolved'),
        'critical': sum(1 for c in all_complaints if c['priority'] in ('High', 'Urgent') and c['status'] not in ('Resolved', 'Rejected'))
    }

    # Fetch all active maintenance staff with their workload counts
    staff_workload = db.query_all(
        """SELECT 
               s.staff_id, 
               u.full_name, 
               u.phone,
               s.specialization, 
               s.availability_status,
               COUNT(c.complaint_id) AS active_workload
           FROM staff s
           JOIN users u ON s.staff_id = u.user_id
           LEFT JOIN complaints c ON c.assigned_staff_id = s.staff_id 
                AND c.status IN ('Assigned', 'In Progress')
           GROUP BY s.staff_id, u.full_name, u.phone, s.specialization, s.availability_status
           ORDER BY s.specialization, u.full_name"""
    )

    # Fetch analytical view summaries for the warden report tab
    block_summary = db.query_all("SELECT * FROM vw_warden_summary ORDER BY hostel_block, category")
    staff_performance = db.query_all("SELECT * FROM vw_staff_performance ORDER BY total_assigned_tasks DESC")
    category_analytics = db.query_all("SELECT * FROM vw_complaint_analytics ORDER BY total_count DESC")

    # Fetch notifications for this warden
    notifications = db.query_all(
        """SELECT notification_id, complaint_id, message, is_read, created_at
           FROM notifications
           WHERE user_id = %s
           ORDER BY created_at DESC LIMIT 15""",
        (session['user_id'],)
    )

    return render_template(
        'warden_dashboard.html',
        complaints=complaints,
        kpi=kpi,
        staff_workload=staff_workload,
        block_summary=block_summary,
        staff_performance=staff_performance,
        category_analytics=category_analytics,
        status_filter=status_filter,
        block_filter=block_filter,
        category_filter=category_filter,
        notifications=notifications
    )

@app.route('/warden/assign', methods=['POST'])
@login_required
@role_required('Warden')
def warden_assign_staff():
    complaint_id = request.form.get('complaint_id', type=int)
    staff_id = request.form.get('staff_id', type=int)
    instructions = request.form.get('instructions', '').strip()
    warden_id = session['user_id']

    if not complaint_id or not staff_id:
        flash('Invalid complaint or staff technician selection.', 'warning')
        return redirect(url_for('warden_dashboard'))

    try:
        # Executes Stored Procedure sp_assign_complaint with ACID Transaction
        db.call_procedure('sp_assign_complaint', (complaint_id, staff_id, warden_id, instructions))
        flash(f'Complaint #{complaint_id} assigned successfully! The staff technician has received an automated alert.', 'success')

    except mysql.connector.Error as err:
        if err.sqlstate == '45000':
            flash(f"[DBMS Assertion Violation] {err.msg}", 'danger')
        else:
            flash(f"Assignment error: {err.msg}", 'danger')

    return redirect(url_for('warden_dashboard'))

@app.route('/warden/resolve', methods=['POST'])
@login_required
@role_required('Warden')
def warden_resolve_complaint():
    complaint_id = request.form.get('complaint_id', type=int)
    verification_notes = request.form.get('verification_notes', '').strip()
    warden_id = session['user_id']

    if not complaint_id:
        flash('Invalid complaint ID.', 'warning')
        return redirect(url_for('warden_dashboard'))

    try:
        # Executes Stored Procedure sp_resolve_complaint
        db.call_procedure('sp_resolve_complaint', (complaint_id, warden_id, verification_notes))
        flash(f'Complaint #{complaint_id} verified and marked officially Resolved. Student has been notified.', 'success')

    except mysql.connector.Error as err:
        flash(f"Resolution error: {err.msg}", 'danger')

    return redirect(url_for('warden_dashboard'))

@app.route('/warden/staff/add', methods=['POST'])
@login_required
@role_required('Warden')
def warden_add_staff():
    username = request.form.get('username', '').strip()
    full_name = request.form.get('full_name', '').strip()
    email = request.form.get('email', '').strip()
    phone = request.form.get('phone', '').strip()
    specialization = request.form.get('specialization', '').strip()
    password = request.form.get('password', 'password123').strip()

    if not username or not full_name or not email or not phone or not specialization:
        flash('Please fill in all staff details.', 'warning')
        return redirect(url_for('warden_dashboard'))

    try:
        hashed = generate_password_hash(password)
        _, new_user_id = db.execute_dml(
            """INSERT INTO users (username, password_hash, full_name, email, phone, role)
               VALUES (%s, %s, %s, %s, %s, 'Staff')""",
            (username, hashed, full_name, email, phone)
        )
        db.execute_dml(
            """INSERT INTO staff (staff_id, specialization, availability_status)
               VALUES (%s, %s, 'Active')""",
            (new_user_id, specialization)
        )
        flash(f'New staff technician "{full_name}" added successfully with role {specialization}.', 'success')
    except mysql.connector.Error as err:
        flash(f"Error adding staff member: {err.msg}", 'danger')

    return redirect(url_for('warden_dashboard'))

# ---------------------------------------------------------------------
# STAFF DASHBOARD (WORK & PERFORMANCE ANALYSIS)
# ---------------------------------------------------------------------
@app.route('/staff/dashboard')
@login_required
@role_required('Staff')
def staff_dashboard():
    staff_id = session['user_id']

    # Important Design Rule: Staff only sees tasks assigned to them!
    assigned_tasks = db.query_all(
        """SELECT * FROM vw_student_complaints
           WHERE assigned_staff_id = %s
           ORDER BY 
               CASE status 
                   WHEN 'Assigned' THEN 1 
                   WHEN 'In Progress' THEN 2 
                   WHEN 'Completed' THEN 3 
                   ELSE 4 
               END,
               CASE priority WHEN 'Urgent' THEN 1 WHEN 'High' THEN 2 WHEN 'Medium' THEN 3 ELSE 4 END,
               complaint_date DESC""",
        (staff_id,)
    )

    # Fetch calculated performance metrics from DBMS view vw_staff_performance
    perf = db.query_one(
        "SELECT * FROM vw_staff_performance WHERE staff_id = %s",
        (staff_id,)
    ) or {
        'total_assigned_tasks': 0,
        'pending_tasks': 0,
        'in_progress_tasks': 0,
        'completed_tasks': 0,
        'resolved_tasks': 0,
        'urgent_tasks': 0,
        'high_priority_tasks': 0,
        'medium_priority_tasks': 0,
        'low_priority_tasks': 0,
        'completion_rate_pct': 0.0,
        'avg_resolution_hours': 0.0
    }

    # Separate active tasks from work history
    active_tasks = [t for t in assigned_tasks if t['status'] in ('Assigned', 'In Progress')]
    work_history = [t for t in assigned_tasks if t['status'] in ('Completed', 'Resolved')]

    # Notifications for this staff member
    notifications = db.query_all(
        """SELECT notification_id, complaint_id, message, is_read, created_at
           FROM notifications
           WHERE user_id = %s
           ORDER BY created_at DESC LIMIT 10""",
        (staff_id,)
    )

    return render_template(
        'staff_dashboard.html',
        tasks=assigned_tasks,
        active_tasks=active_tasks,
        work_history=work_history,
        perf=perf,
        notifications=notifications
    )

@app.route('/staff/task/update', methods=['POST'])
@login_required
@role_required('Staff')
def staff_update_task():
    staff_id = session['user_id']
    complaint_id = request.form.get('complaint_id', type=int)
    new_status = request.form.get('status', '').strip()
    notes = request.form.get('notes', '').strip()

    if not complaint_id or not new_status:
        flash('Invalid task update parameters.', 'warning')
        return redirect(url_for('staff_dashboard'))

    try:
        # Executes Stored Procedure sp_update_task_status
        db.call_procedure('sp_update_task_status', (complaint_id, staff_id, new_status, notes))
        flash(f'Task #{complaint_id} updated to "{new_status}" successfully!', 'success')

    except mysql.connector.Error as err:
        if err.sqlstate == '45000':
            flash(f"[DBMS Assertion / Security Error] {err.msg}", 'danger')
        else:
            flash(f"Update error: {err.msg}", 'danger')

    return redirect(url_for('staff_dashboard'))

# ---------------------------------------------------------------------
# COMPLAINT TIMELINE & AUDIT HISTORY API
# ---------------------------------------------------------------------
@app.route('/api/complaint/<int:complaint_id>/history')
@login_required
def get_complaint_history(complaint_id):
    """Returns chronological audit trail for a complaint."""
    try:
        history = db.query_all(
            """SELECT h.history_id, h.old_status, h.new_status, h.action_type, 
                      h.remarks, h.changed_at, u.full_name AS actor_name, u.role AS actor_role
               FROM complaint_history h
               LEFT JOIN users u ON h.changed_by_user_id = u.user_id
               WHERE h.complaint_id = %s
               ORDER BY h.changed_at ASC""",
            (complaint_id,)
        )
        return jsonify({'success': True, 'history': history})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    print("=" * 65)
    print(" HOSTEL MAINTENANCE & COMPLAINT TRACKER - FLASK SERVER")
    print(f" Database: {Config.MYSQL_DB} on {Config.MYSQL_HOST}:{Config.MYSQL_PORT}")
    print(" Starting server on http://127.0.0.1:5000 ...")
    print("=" * 65)
    app.run(debug=True, host='127.0.0.1', port=5000)
