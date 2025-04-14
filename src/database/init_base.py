import sqlite3

conn = sqlite3.connect("data/base.db")
cursor = conn.cursor()

# Exemple de structure de table (à adapter à ton modèle AD)
cursor.execute("""
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY ,
    sam_acount_name TEXT NOT NULL,
    name TEXT NOT NULL,
    email TEXT,
    dn TEXT
);
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS groups (
    id INTEGER PRIMARY KEY ,
    name TEXT NOT NULL,
    dn TEXT
);
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS user_group (
    user_id INTEGER,
    group_id INTEGER,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (group_id) REFERENCES groups(id)
);
""")

conn.commit()
conn.close()

print("Base de données créée.")
