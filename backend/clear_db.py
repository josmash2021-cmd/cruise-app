"""Clear all user-related data from the database to start fresh."""
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "cruise.db")
db = sqlite3.connect(DB_PATH)
c = db.cursor()

# Get all tables
c.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = [r[0] for r in c.fetchall()]
print("Tables found:", tables)

# Count before
for t in tables:
    c.execute(f"SELECT COUNT(*) FROM {t}")
    print(f"  {t}: {c.fetchone()[0]} rows")

# Clear all data (order matters for FK constraints)
clear_order = [
    "documents",
    "trips",
    "vehicles",
    "offers",
    "users",
]

for t in clear_order:
    if t in tables:
        c.execute(f"DELETE FROM {t}")
        print(f"Deleted all rows from {t}")

# Also clear any remaining tables not in the ordered list
for t in tables:
    if t not in clear_order and t != "sqlite_sequence":
        try:
            c.execute(f"DELETE FROM {t}")
            print(f"Deleted all rows from {t}")
        except Exception as e:
            print(f"  Could not clear {t}: {e}")

# Reset auto-increment counters
try:
    c.execute("DELETE FROM sqlite_sequence")
    print("Reset auto-increment counters")
except Exception:
    pass  # table may not exist

db.commit()
db.close()
print("\nDatabase cleared successfully. All user accounts removed.")
