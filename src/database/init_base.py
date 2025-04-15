import sqlite3
import os


script_dir = os.path.dirname(os.path.abspath(__file__))
db_path = os.path.join(script_dir, "base.db")

conn = sqlite3.connect(db_path)
cursor = conn.cursor()


# Exemple de structure de table (à adapter à ton modèle AD)
cursor.execute("""
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY ,
    sam_acount_name TEXT NOT NULL,
    name TEXT NOT NULL,
    email TEXT
);
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS groups (
    id TEXT PRIMARY KEY ,
    name TEXT NOT NULL,
    dn TEXT
);
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS user_group (
    user_id TEXT,
    group_id TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (group_id) REFERENCES groups(id)
);
""")

conn.commit()
conn.close()

print("Base de données créée.")
