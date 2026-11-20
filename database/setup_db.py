"""
Database Initialization Script for Hostel Maintenance and Complaint Tracker
Executes schema, triggers, views, procedures, and seed data in MySQL.
"""
import sys
import os
import argparse
import mysql.connector

# Add parent directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
try:
    from config import Config
except ImportError:
    class Config:
        MYSQL_HOST = 'localhost'
        MYSQL_USER = 'root'
        MYSQL_PASSWORD = ''
        MYSQL_PORT = 3306
        MYSQL_DB = 'hostel_tracker'

def read_sql_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return f.read()

def execute_sql_script(cursor, script_content):
    # Splits by custom delimiters or semicolons safely
    statements = []
    current_statement = []
    delimiter = ';'
    
    lines = script_content.splitlines()
    for line in lines:
        stripped = line.strip()
        if stripped.upper().startswith('DELIMITER'):
            parts = stripped.split()
            if len(parts) >= 2:
                delimiter = parts[1]
            continue
            
        if delimiter == ';':
            if line.endswith(';'):
                current_statement.append(line[:-1])
                stmt = '\n'.join(current_statement).strip()
                if stmt:
                    statements.append(stmt)
                current_statement = []
            else:
                current_statement.append(line)
        else:
            if stripped.endswith(delimiter):
                line_without_delim = line[:line.rfind(delimiter)]
                current_statement.append(line_without_delim)
                stmt = '\n'.join(current_statement).strip()
                if stmt:
                    statements.append(stmt)
                current_statement = []
            else:
                current_statement.append(line)
                
    if current_statement:
        stmt = '\n'.join(current_statement).strip()
        if stmt:
            statements.append(stmt)
            
    for statement in statements:
        stmt = statement.strip()
        # Skip pure comments or empty lines
        if not stmt or stmt.startswith('--') and '\n' not in stmt:
            continue
        try:
            cursor.execute(stmt)
        except mysql.connector.Error as err:
            print(f"SQL Error in statement:\n{stmt[:120]}...\nDetails: {err}\n")
            raise

def main():
    parser = argparse.ArgumentParser(description="Initialize Hostel Tracker MySQL Database")
    parser.add_argument("--host", default=Config.MYSQL_HOST, help="MySQL Host")
    parser.add_argument("--user", default=Config.MYSQL_USER, help="MySQL User")
    parser.add_argument("--password", default=Config.MYSQL_PASSWORD, help="MySQL Password")
    parser.add_argument("--port", type=int, default=Config.MYSQL_PORT, help="MySQL Port")
    args = parser.parse_args()

    print("=" * 65)
    print(" HOSTEL MAINTENANCE & COMPLAINT TRACKER - DATABASE SETUP")
    print("=" * 65)

    base_dir = os.path.dirname(os.path.abspath(__file__))
    sql_files = [
        ("Database Schema (DDL)", os.path.join(base_dir, "schema.sql")),
        ("Triggers & DBMS Assertions", os.path.join(base_dir, "triggers_and_assertions.sql")),
        ("Analytical Views", os.path.join(base_dir, "views.sql")),
        ("Stored Procedures & Transactions", os.path.join(base_dir, "procedures.sql")),
        ("Sample Seed Data (DML)", os.path.join(base_dir, "seed_data.sql")),
    ]

    password = args.password
    conn = None

    # Try connection, prompt if password fails
    while True:
        try:
            print(f"Connecting to MySQL server at {args.host}:{args.port} as '{args.user}'...")
            conn = mysql.connector.connect(
                host=args.host,
                user=args.user,
                password=password,
                port=args.port
            )
            print(" Connected to MySQL server successfully!")
            break
        except mysql.connector.Error as err:
            if err.errno == 1045: # Access denied
                print(f"\n[!] Access denied for user '{args.user}'.")
                print("Tip: If you're not sure, you can set it in MySQL Workbench using:")
                print("     ALTER USER 'root'@'localhost' IDENTIFIED BY 'root'; FLUSH PRIVILEGES;")
                try:
                    password = input("\nPlease enter your MySQL root password (visible): ").strip()
                except Exception:
                    password = ""
            else:
                print(f"[X] Connection Error: {err}")
                sys.exit(1)

    cursor = conn.cursor()

    try:
        for title, path in sql_files:
            print(f"\n[>] Executing: {title} ...")
            if not os.path.exists(path):
                print(f"[!] File not found: {path}")
                continue
            content = read_sql_file(path)
            execute_sql_script(cursor, content)
            conn.commit()
            print(f"     Done.")

        # Save the valid password to .env for future app usage
        env_path = os.path.join(base_dir, '..', '.env')
        with open(env_path, 'w', encoding='utf-8') as f:
            f.write(f"MYSQL_HOST={args.host}\n")
            f.write(f"MYSQL_USER={args.user}\n")
            f.write(f"MYSQL_PASSWORD={password}\n")
            f.write(f"MYSQL_PORT={args.port}\n")
            f.write(f"MYSQL_DB=hostel_tracker\n")
            f.write("SECRET_KEY=hostel_tracker_secret_super_key_2026\n")
        print(f"\n Credentials successfully saved to {os.path.abspath(env_path)}")

        print("\n" + "=" * 65)
        print(" DATABASE SETUP COMPLETED SUCCESSFULLY!")
        print("=" * 65)
        print("Default Test Accounts:")
        print("  1. Student:  Username: student1     Password: password123")
        print("  2. Warden:   Username: warden1      Password: password123")
        print("  3. Staff:    Username: plumber1     Password: password123")
        print("  4. Staff:    Username: electrician1 Password: password123")
        print("=" * 65)

    except Exception as e:
        print(f"\n[X] Error during execution: {e}")
        conn.rollback()
    finally:
        cursor.close()
        conn.close()

if __name__ == '__main__':
    main()
