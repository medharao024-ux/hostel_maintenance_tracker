"""
Database Helper Module for Hostel Maintenance and Complaint Tracker
Provides direct, real-time MySQL connectivity via mysql-connector-python.
Every query directly queries the live MySQL database.
"""
import mysql.connector
from mysql.connector import Error
from config import Config

def get_db_connection():
    """Returns a direct connection to the MySQL database."""
    try:
        connection = mysql.connector.connect(
            host=Config.MYSQL_HOST,
            user=Config.MYSQL_USER,
            password=Config.MYSQL_PASSWORD,
            port=Config.MYSQL_PORT,
            database=Config.MYSQL_DB,
            charset='utf8mb4',
            collation='utf8mb4_unicode_ci'
        )
        return connection
    except Error as e:
        print(f"[X] Database Connection Error: {e}")
        raise e

def query_one(sql, params=None):
    """Executes a SELECT query and returns a single row as a dictionary."""
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True, buffered=True)
    try:
        cursor.execute(sql, params or ())
        row = cursor.fetchone()
        return row
    finally:
        cursor.close()
        conn.close()

def query_all(sql, params=None):
    """Executes a SELECT query and returns all matching rows as dictionaries."""
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True, buffered=True)
    try:
        cursor.execute(sql, params or ())
        rows = cursor.fetchall()
        return rows
    finally:
        cursor.close()
        conn.close()

def execute_dml(sql, params=None):
    """
    Executes an INSERT, UPDATE, or DELETE statement.
    Returns (affected_rows, last_insert_id).
    Catches and re-raises MySQL exceptions (e.g. trigger assertions).
    """
    conn = get_db_connection()
    cursor = conn.cursor(buffered=True)
    try:
        cursor.execute(sql, params or ())
        conn.commit()
        last_id = cursor.lastrowid
        row_count = cursor.rowcount
        return row_count, last_id
    except Error as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()

def call_procedure(proc_name, params=None):
    """Executes a MySQL Stored Procedure safely."""
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.callproc(proc_name, params or ())
        conn.commit()
        return True
    except Error as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()
