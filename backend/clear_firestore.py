"""Clear all Firestore collections: users, drivers, clients, verifications, trips."""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

try:
    import firestore_sync
    firestore_sync._ensure_init()
    db = firestore_sync._db
    if db is None:
        print("Firestore not available, skipping.")
        sys.exit(0)
except Exception as e:
    print(f"Firestore init failed: {e}")
    sys.exit(0)

COLLECTIONS = ["users", "drivers", "clients", "verifications", "trips", "chat_messages", "notifications"]

for col_name in COLLECTIONS:
    col = db.collection(col_name)
    docs = col.stream()
    count = 0
    for doc in docs:
        doc.reference.delete()
        count += 1
    print(f"Deleted {count} docs from '{col_name}'")

print("\nFirestore cleared successfully.")
