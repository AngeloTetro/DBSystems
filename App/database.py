import os
import oracledb


def get_connection():
    user = os.getenv("DB_USER", "test")
    password = os.getenv("DB_PASSWORD", "test1234")
    dsn = os.getenv("DB_DSN", "localhost:1521/xe")
    return oracledb.connect(user=user, password=password, dsn=dsn)
