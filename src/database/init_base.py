import sqlite3
import os


script_dir = os.path.dirname(os.path.abspath(__file__))
db_path = os.path.join(script_dir, "base.db")

conn = sqlite3.connect(db_path)
cursor = conn.cursor()



cursor.execute("""
CREATE TABLE IF NOT EXISTS T_ASR_AD_USERS_1 (
    id INTEGER PRIMARY KEY AUTO_INCREMENT,
    user_guid TEXT NOT NULL,
    sam_acount_name TEXT NOT NULL,
    name TEXT NOT NULL,
    email TEXT
);
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS T_ASR_AD_GROUPS_1 (
    id INTEGER PRIMARY KEY AUTO_INCREMENT ,
    group_guid TEXT,
    name TEXT NOT NULL,
    dn TEXT
);
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS T_ASR_AD_USERS_GROUPS_1 (
    user_id TEXT,
    group_id TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (group_id) REFERENCES groups(id)
);
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS T_ASR_AD_TRANSCO_1 (
    codetrans TEXT,
    group_id TEXT,
    app_name TEXT,
    flag_migrate INT,
    FOREIGN KEY (group_id) REFERENCES groups(id)
);
""")
#FOREIGN KEY (codetrans) REFERENCES TEPHABL1(codetrans),

conn.commit()
conn.close()

print("Base de données créée.")
