import os

# Directly set fallback defaults so MySQL connection works out of the box
DEFAULT_MYSQL_HOST = 'localhost'
DEFAULT_MYSQL_USER = 'root'
DEFAULT_MYSQL_PASSWORD = '948040@medha'
DEFAULT_MYSQL_PORT = 3306
DEFAULT_MYSQL_DB = 'hostel_tracker'
DEFAULT_SECRET_KEY = 'hostel_maintenance_super_secret_key_2026'

# Automatically load from .env file if it exists
env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env')
if os.path.exists(env_path):
    try:
        with open(env_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    k, v = line.split('=', 1)
                    os.environ[k.strip()] = v.strip()
    except Exception:
        pass

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', DEFAULT_SECRET_KEY)
    MYSQL_HOST = os.environ.get('MYSQL_HOST', DEFAULT_MYSQL_HOST)
    MYSQL_USER = os.environ.get('MYSQL_USER', DEFAULT_MYSQL_USER)
    MYSQL_PASSWORD = os.environ.get('MYSQL_PASSWORD', DEFAULT_MYSQL_PASSWORD)
    MYSQL_PORT = int(os.environ.get('MYSQL_PORT', DEFAULT_MYSQL_PORT))
    MYSQL_DB = os.environ.get('MYSQL_DB', DEFAULT_MYSQL_DB)
