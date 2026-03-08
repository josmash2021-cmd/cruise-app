"""One-time script to backfill verification file URLs into the users table."""
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "cruise.db")
DOCS_DIR = os.path.join(os.path.dirname(__file__), "uploads", "documents")

db = sqlite3.connect(DB_PATH)
c = db.cursor()

files = os.listdir(DOCS_DIR)
user_files = {}
for f in files:
    parts = f.replace("verify_", "").split("_")
    uid = int(parts[0])
    # label is everything between uid and the last part (timestamp.ext)
    label = "_".join(parts[1:-1])
    if uid not in user_files:
        user_files[uid] = {}
    user_files[uid][label] = f"/uploads/documents/{f}"

for uid, urls in sorted(user_files.items()):
    print(f"User {uid}: {urls}")
    updates = []
    if "selfie" in urls:
        updates.append(("selfie_url", urls["selfie"]))
    if "id_doc" in urls:
        updates.append(("id_photo_url", urls["id_doc"]))
    if "license_front" in urls:
        updates.append(("license_front_url", urls["license_front"]))
        updates.append(("id_photo_url", urls["license_front"]))
    if "license_back" in urls:
        updates.append(("license_back_url", urls["license_back"]))
    if "insurance" in urls:
        updates.append(("insurance_url", urls["insurance"]))
    for col, val in updates:
        c.execute(
            f"UPDATE users SET {col}=? WHERE id=? AND ({col} IS NULL OR {col}='')",
            (val, uid),
        )
        if c.rowcount > 0:
            print(f"  -> Set {col} = {val}")

db.commit()
db.close()
print("Done backfilling")
