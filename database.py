import sqlite3, os, hashlib, time

DB_PATH = os.path.join(os.path.dirname(__file__), "kwara_fees.db")

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn

def init_db():
    conn = get_db()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            matric TEXT UNIQUE NOT NULL,
            fullname TEXT NOT NULL,
            department TEXT NOT NULL,
            level TEXT NOT NULL,
            session TEXT NOT NULL DEFAULT '2024/2025',
            created_at TEXT DEFAULT (datetime('now','localtime'))
        );

        CREATE TABLE IF NOT EXISTS fees (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fee_type TEXT NOT NULL,
            amount REAL NOT NULL,
            session TEXT NOT NULL,
            description TEXT DEFAULT ''
        );

        CREATE TABLE IF NOT EXISTS payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER NOT NULL,
            fee_id INTEGER NOT NULL,
            amount_paid REAL NOT NULL,
            payment_date TEXT DEFAULT (date('now')),
            receipt_no TEXT UNIQUE NOT NULL,
            payment_method TEXT DEFAULT 'Cash',
            verified INTEGER DEFAULT 0,
            created_at TEXT DEFAULT (datetime('now','localtime')),
            FOREIGN KEY(student_id) REFERENCES students(id),
            FOREIGN KEY(fee_id) REFERENCES fees(id)
        );

        CREATE TABLE IF NOT EXISTS admins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            fullname TEXT NOT NULL
        );
    """)
    # Seed default admin if not exists
    cur = conn.execute("SELECT COUNT(*) FROM admins")
    if cur.fetchone()[0] == 0:
        pw = hashlib.sha256("admin123".encode()).hexdigest()
        conn.execute("INSERT INTO admins (username, password_hash, fullname) VALUES (?,?,?)",
                     ("admin", pw, "System Admin"))
    # Seed default fee types if not exists
    cur = conn.execute("SELECT COUNT(*) FROM fees")
    if cur.fetchone()[0] == 0:
        fees_data = [
            ("School Fees (Session)", 85000, "2024/2025", "Full session school fees"),
            ("Acceptance Fee", 15000, "2024/2025", "New student acceptance"),
            ("Development Levy", 10000, "2024/2025", "Development levy"),
            ("Examination Fee", 5000, "2024/2025", "Per semester"),
            ("Library Fee", 3000, "2024/2025", "Library access"),
        ]
        conn.executemany("INSERT INTO fees (fee_type, amount, session, description) VALUES (?,?,?,?)", fees_data)
    conn.commit()
    conn.close()

def generate_receipt_no():
    t = int(time.time())
    return f"KWP/{t % 1000000:06d}"

def verify_admin(username, password):
    conn = get_db()
    pw_hash = hashlib.sha256(password.encode()).hexdigest()
    cur = conn.execute("SELECT * FROM admins WHERE username=? AND password_hash=?", (username, pw_hash))
    row = cur.fetchone()
    conn.close()
    return row

if __name__ == "__main__":
    init_db()
    print("✅ Database initialized successfully.")