@echo off
title Hostel Maintenance and Complaint Tracker
echo ===================================================================
echo     HOSTEL MAINTENANCE AND COMPLAINT TRACKER
echo     Connected to Live MySQL 8.0 Engine
echo ===================================================================
echo.

:: Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python is not found in your system PATH.
    echo Please install Python 3.10+ and ensure 'Add to PATH' is checked.
    pause
    exit /b 1
)

:: Option prompt
echo Select an option:
echo [1] Start Flask Web Application
echo [2] Initialize / Reset Database in MySQL
echo [3] Run DBMS Viva Evaluation Queries in MySQL
echo.
set /p opt="Enter option (1/2/3) [Default 1]: "
if "%opt%"=="" set opt=1

if "%opt%"=="2" (
    echo.
    echo Initializing MySQL Database...
    python database/setup_db.py
    echo.
    pause
    exit /b 0
)

if "%opt%"=="3" (
    echo.
    echo Opening dbms_queries_evaluation.sql in default editor / workbench...
    start notepad.exe database/dbms_queries_evaluation.sql
    exit /b 0
)

echo.
echo Starting HostelCare Web Application on http://127.0.0.1:5000 ...
python app.py
pause
