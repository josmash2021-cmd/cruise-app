import sqlite3
c = sqlite3.connect(r'C:\Users\josma\cruise-app\backend\cruise.db').cursor()
c.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = [r[0] for r in c.fetchall()]
for t in tables:
    c.execute(f"SELECT COUNT(*) FROM {t}")
    print(f"{t}: {c.fetchone()[0]} rows")
