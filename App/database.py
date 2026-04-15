import os
import oracledb


def get_connection():
    user = os.getenv("DB_USER", "stageup_user")
    password = os.getenv("DB_PASSWORD", "stageup_pwd")
    dsn = os.getenv("DB_DSN", "localhost:1521/XEPDB1")
    return oracledb.connect(user=user, password=password, dsn=dsn)
