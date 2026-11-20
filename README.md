# Hostel Maintenance and Complaint Tracker

A complete, production-ready full-stack web application designed for hostel complaint registration, technician task dispatching, and resolution auditing. Built with **Flask (Python)** and a **MySQL 8.0** relational database engine implementing advanced DBMS features including **Triggers**, **Business Assertions**, **Analytical Views**, **Stored Procedures**, and **ACID Transactions**.

---

## 📌 Project Objectives & Roadmap

This project achieves all 5 stages from the development roadmap:
1. **Stage 1 - Professional UI/UX**: Clean landing page with role-based tabs (Student, Warden, Staff) and modern dashboards with workflow timelines.
2. **Stage 2 - MySQL Database**: Normalized relational schema with Primary/Foreign keys, `CHECK` constraints, indexes, and realistic seed data.
3. **Stage 3 - Flask Backend**: Direct, live MySQL connection without caching. **Any SQL statement executed directly in MySQL Workbench or CLI immediately updates the web application upon refresh.**
4. **Stage 4 - Advanced DBMS Features**:
   - **Triggers**: Automated audit trail logging in `complaint_history` and real-time student/technician alerts in `notifications`.
   - **DBMS Assertions**: Custom invariant checking with `SIGNAL SQLSTATE '45000'` (preventing duplicate active complaints and preventing assignment to staff who are On Leave).
   - **Analytical Views**: `vw_student_complaints`, `vw_warden_summary`, `vw_staff_performance`, `vw_complaint_analytics`.
   - **Stored Procedures & Transactions**: `sp_assign_complaint`, `sp_update_task_status`, `sp_resolve_complaint` with `START TRANSACTION`, `COMMIT`, and `ROLLBACK`.
5. **Stage 5 - Testing & Demonstration**: End-to-end evaluation script (`database/dbms_queries_evaluation.sql`) covering Joins, Subqueries, Aggregations, and Assertion tests for college evaluation/viva.

---

## 🔄 The 5-Step Resolution Workflow

```
Student submits complaint
        ↓
Warden reviews & assigns staff technician
        ↓
Staff works on the complaint (updates to In Progress)
        ↓
Staff updates completion status (Work Completed)
        ↓
Warden monitors & verifies resolution
        ↓
Complaint Resolved (Closed)
```

---

## 👥 Role Responsibilities

### 1. Student Dashboard
- **File New Complaints**: Categorized by Plumbing, Electrical, Carpentry, Cleaning, Internet/Wi-Fi, and Appliances with urgency/priority levels.
- **Track Complaint Status**: Interactive 5-stage visual progress timeline (`Submitted` $\rightarrow$ `Assigned` $\rightarrow$ `In Progress` $\rightarrow$ `Work Done` $\rightarrow$ `Resolved`).
- **Audit Trail**: View chronological timestamped logs generated automatically by database triggers.
- **Trigger Notifications**: In-app notifications received whenever status updates occur.

### 2. Warden Dashboard
- **Overview KPI Cards**: Total complaints, Pending triage, Assigned, In Progress, Completed, Resolved, Critical.
- **Staff Assignment**: Modal to allocate complaints to available technicians.
- **Resolution Verification**: Review technician work notes and mark tickets officially `Resolved`.
- **Technician Directory**: Manage staff, view current active workloads, and register new personnel.
- **Analytical Reports**: Real-time charts by Category and Status, plus block-wise and staff performance matrices.

### 3. Staff Dashboard (Work Analysis)
> **Key Design Rule**: Maintenance technicians **only see complaints assigned directly to them**.
- **Assigned Tasks**: Total complaints assigned.
- **Pending Tasks**: Work not yet started.
- **In Progress**: Tasks currently being handled.
- **Completed Tasks**: Successfully finished complaints.
- **Priority Analysis**: Urgent, High, Medium, and Low workload distribution.
- **Work History**: Past successfully completed tickets with resolution notes.
- **Performance Analytics**: Completion rate (%) and average resolution time in hours computed by MySQL view `vw_staff_performance`.
- **Status Updates**: Move assigned tickets to `In Progress` or `Completed` with work notes.

---

## 🗄️ Database Architecture & DBMS Highlights

### Core Tables
- `users`: Core credentials and roles (`Student`, `Warden`, `Staff`).
- `students`: Roll number, hostel block, room number.
- `staff`: Specialization (Plumbing, Electrical, Carpentry, Cleaning, etc.) and availability status (`Active`, `On Leave`).
- `complaints`: Complaint title, description, priority, status, timestamps (`created_at`, `assigned_at`, `completed_at`, `resolved_at`).
- `complaint_history`: Audit trail table recording state transitions, actor ID, action type, and remarks.
- `notifications`: Notifications for students and technicians generated automatically by triggers.

### DBMS Triggers & Assertions (`database/triggers_and_assertions.sql`)
1. **Assertion 1 (`trg_prevent_duplicate_active_complaint`)**:
   - Enforces business invariant: Rejects duplicate active complaints for the same student, room, and category using:
     ```sql
     SIGNAL SQLSTATE '45000'
     SET MESSAGE_TEXT = 'DBMS Assertion Violation: An active complaint already exists for this room and category.';
     ```
2. **Assertion 2 (`trg_verify_staff_availability`)**:
   - Enforces invariant: Rejects assigning a complaint to a technician whose `availability_status` is `'On Leave'` or `'Inactive'`.
3. **Trigger 3 (`trg_complaint_status_notification`)**:
   - Automatically inserts an audit record into `complaint_history` and a notification into `notifications` whenever `status` changes.
4. **Trigger 4 (`trg_complaint_assigned_alert`)**:
   - Automatically sends an alert notification to the assigned technician.
5. **Trigger 5 (`trg_record_timestamps_before_update`)**:
   - Automatically sets `assigned_at`, `completed_at`, and `resolved_at` upon state transition.

### Stored Procedures with ACID Transactions (`database/procedures.sql`)
- `sp_assign_complaint(complaint_id, staff_id, warden_id, notes)`
- `sp_update_task_status(complaint_id, staff_id, new_status, notes)`
- `sp_resolve_complaint(complaint_id, warden_id, notes)`
All procedures use `START TRANSACTION`, row-level locking (`FOR UPDATE`), and `ROLLBACK` on error.

---

## 🚀 Quick Setup & How to Run

### Step 1: Clone or Extract the Project
Extract `hostel_maintenance_tracker.zip` or open the project folder in your terminal / VS Code.

### Step 2: Initialize Database in MySQL
Make sure your MySQL Server 8.0 is running.
Run the one-click database setup script:
```bash
python database/setup_db.py
```
*(If prompted, enter your MySQL root password. The script will automatically create `hostel_tracker`, all tables, triggers, views, procedures, and seed records, and save your credentials in `.env`)*

### Step 3: Start the Flask Application
Run:
```bash
python app.py
```
*(Or double-click `run.bat` on Windows!)*

Open your browser at:
```
http://127.0.0.1:5000
```

---

## 🔑 Default Test Accounts

| Role | Username | Password | Notes / Description |
|---|---|---|---|
| **Student** | `student1` | `password123` | Medha Rao (Block A, Room 101) |
| **Student** | `student2` | `password123` | Rahul Sharma (Block B, Room 205) |
| **Warden** | `warden1` | `password123` | Dr. Ramesh Hegde (Chief Warden) |
| **Staff (Plumbing)** | `plumber1` | `password123` | Suresh Kumar (Active Plumber) |
| **Staff (Electrical)**| `electrician1` | `password123` | Mahesh Verma (Active Electrician) |
| **Staff (On Leave)** | `staff_leave` | `password123` | Vikram Singh (Used for Assertion 2 test) |

---

## 🧪 Live MySQL Synchronization Demonstration

To verify that the project is directly connected to MySQL:
1. Open **MySQL Workbench**.
2. Run this query:
   ```sql
   USE hostel_tracker;
   UPDATE complaints SET status = 'Resolved' WHERE complaint_id = 1;
   ```
3. Refresh the Student or Warden dashboard in your web browser.
4. **Notice**: Complaint #1 immediately reflects as **Resolved** with updated timeline and notifications, proving live database synchronization!

---

## 🎓 College Viva & Evaluation SQL Queries

For your project evaluation, open and execute `database/dbms_queries_evaluation.sql`. It includes:
- **Joins**: Multi-table inner joins and left joins with students and technicians.
- **Aggregations**: `GROUP BY` and `HAVING` queries for block statistics.
- **Subqueries**: `IN`, `EXISTS`, and scalar subqueries comparing against average resolution times.
- **View Queries**: Querying `vw_staff_performance` and `vw_warden_summary`.
- **Trigger Tests**: Verifying notifications and audit logs on status update.
- **Assertion Tests**: Triggering deliberate `SQLSTATE '45000'` constraint errors to demonstrate database-level validation.
