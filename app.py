"""
Offline School Fees Recording & Verification System with QR Code
Kwara State Polytechnic
Flask + SQLite + QR Code
"""
import os, sqlite3, qrcode, io, base64, hashlib, json
from datetime import date, datetime
from flask import Flask, render_template, request, redirect, url_for, session, jsonify, send_file
from database import get_db, init_db, generate_receipt_no

app = Flask(__name__)
app.secret_key = os.urandom(24)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# ─── Auth ────────────────────────────────────────────────────────────────────
@app.before_request
def require_login():
    if request.endpoint in ('login', 'static', 'public_verify', 'verify_page', 'verify_qr_image'):
        return
    if request.path.startswith('/static') or request.path.startswith('/p/'):
        return
    if 'admin_id' not in session:
        return redirect(url_for('login'))

# ─── Login ───────────────────────────────────────────────────────────────────
@app.route('/', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        from database import verify_admin
        row = verify_admin(request.form['username'], request.form['password'])
        if row:
            session['admin_id'] = row['id']
            session['admin_name'] = row['fullname']
            return redirect(url_for('dashboard'))
        return render_template('login.html', error='Invalid credentials')
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

# ─── Dashboard ────────────────────────────────────────────────────────────────
@app.route('/dashboard')
def dashboard():
    conn = get_db()
    students = conn.execute("SELECT COUNT(*) FROM students").fetchone()[0]
    payments_today = conn.execute("SELECT COUNT(*) FROM payments WHERE date(payment_date)=date('now')").fetchone()[0]
    amount_today = conn.execute("SELECT COALESCE(SUM(amount_paid),0) FROM payments WHERE date(payment_date)=date('now')").fetchone()[0]
    total = conn.execute("SELECT COALESCE(SUM(amount_paid),0) FROM payments").fetchone()[0]
    recent = conn.execute("""
        SELECT p.*, s.fullname, s.matric, s.department, s.level
        FROM payments p JOIN students s ON p.student_id=s.id
        ORDER BY p.id DESC LIMIT 10
    """).fetchall()
    conn.close()
    return render_template('dashboard.html', students=students, payments_today=payments_today,
                           amount_today=amount_today, total=total, recent=recent)

# ─── Students ─────────────────────────────────────────────────────────────────
@app.route('/students')
def students_page():
    conn = get_db()
    students = conn.execute("SELECT * FROM students ORDER BY id DESC").fetchall()
    conn.close()
    return render_template('students.html', students=students)

@app.route('/students/add', methods=['POST'])
def add_student():
    conn = get_db()
    try:
        conn.execute("""INSERT INTO students (matric, fullname, department, level, session)
                        VALUES (?,?,?,?,?)""",
                     (request.form['matric'], request.form['fullname'],
                      request.form['department'], request.form['level'], request.form['session']))
        conn.commit()
    except sqlite3.IntegrityError:
        conn.close()
        return render_template('students.html',
                               students=conn.execute("SELECT * FROM students").fetchall(),
                               error="Matric number already exists!")
    conn.close()
    return redirect(url_for('students_page'))

@app.route('/students/<int:sid>')
def student_detail(sid):
    conn = get_db()
    s = conn.execute("SELECT * FROM students WHERE id=?", (sid,)).fetchone()
    payments = conn.execute("""
        SELECT p.*, f.fee_type FROM payments p
        JOIN fees f ON p.fee_id=f.id
        WHERE p.student_id=? ORDER BY p.id DESC
    """, (sid,)).fetchall()
    total_paid = conn.execute("SELECT COALESCE(SUM(amount_paid),0) FROM payments WHERE student_id=?", (sid,)).fetchone()[0]
    # Total expected = sum of all fee amounts for the student's session
    outstanding = max(0, 85000 - total_paid)  # rough estimate
    conn.close()
    if not s:
        return "Student not found", 404
    return render_template('student_detail.html', s=s, payments=payments, outstanding=outstanding)

# ─── Search Student (API) ─────────────────────────────────────────────────────
@app.route('/search_student')
def search_student():
    q = request.args.get('q', '')
    conn = get_db()
    rows = conn.execute("""SELECT * FROM students
                           WHERE matric LIKE ? OR fullname LIKE ? OR department LIKE ?
                           ORDER BY fullname LIMIT 10""",
                        (f'%{q}%', f'%{q}%', f'%{q}%')).fetchall()
    conn.close()
    return jsonify([dict(r) for r in rows])

# ─── Record Payment ───────────────────────────────────────────────────────────
@app.route('/record-payment')
def record_payment_page():
    conn = get_db()
    fees = conn.execute("SELECT * FROM fees ORDER BY fee_type").fetchall()
    conn.close()
    return render_template('record_payment.html', fees=fees)

@app.route('/record-payment', methods=['POST'])
def record_payment():
    student_id = request.form['student_id']
    fee_id = request.form['fee_id']
    amount = float(request.form['amount'])
    method = request.form.get('method', 'Cash')
    receipt_no = generate_receipt_no()

    conn = get_db()
    conn.execute("""INSERT INTO payments (student_id, fee_id, amount_paid, payment_method, receipt_no)
                    VALUES (?,?,?,?,?)""",
                 (student_id, fee_id, amount, method, receipt_no))
    conn.commit()
    conn.close()
    return redirect(url_for('receipt', receipt_no=receipt_no))

# ─── Receipt with QR ──────────────────────────────────────────────────────────
@app.route('/receipt/<path:receipt_no>')
def receipt(receipt_no):
    conn = get_db()
    r = conn.execute("""
        SELECT p.*, s.fullname, s.matric, s.department, s.level, f.fee_type
        FROM payments p
        JOIN students s ON p.student_id=s.id
        JOIN fees f ON p.fee_id=f.id
        WHERE p.receipt_no=?
    """, (receipt_no,)).fetchone()
    conn.close()
    if not r:
        return "Receipt not found", 404

    # Embed simple public verify URL in QR — anyone with the link can verify
    verify_url = url_for('public_verify', receipt_no=r['receipt_no'], _external=True)
    img = qrcode.make(verify_url, error_correction=qrcode.constants.ERROR_CORRECT_H,
                      box_size=8, border=2)
    buf = io.BytesIO()
    img.save(buf, 'PNG')
    qr_b64 = base64.b64encode(buf.getvalue()).decode()
    return render_template('receipt.html', r=r, qr_b64=qr_b64, verify_url=verify_url)

# ─── All Payments ─────────────────────────────────────────────────────────────
@app.route('/payments')
def payments_page():
    conn = get_db()
    payments = conn.execute("""
        SELECT p.*, s.fullname, s.matric, s.department, s.level, f.fee_type
        FROM payments p
        JOIN students s ON p.student_id=s.id
        JOIN fees f ON p.fee_id=f.id
        ORDER BY p.id DESC
    """).fetchall()
    conn.close()
    return render_template('payments.html', payments=payments)

@app.route('/link_verify')
def link_verify():
    """Direct verification via QR-scanned URL — works on any device"""
    receipt_no = request.args.get('receipt_no', '')
    matric = request.args.get('matric', '')
    try:
        amount = float(request.args.get('amount', '0'))
    except ValueError:
        amount = 0
    date = request.args.get('date', '')
    if not (receipt_no and matric and date):
        return render_template('verify.html',
                               result={'valid': False,
                                       'message': 'Missing required data parameters.'})
    conn = get_db()
    p = conn.execute("""
        SELECT p.*, s.fullname, s.matric, s.department, s.level, f.fee_type
        FROM payments p
        JOIN students s ON p.student_id=s.id
        JOIN fees f ON p.fee_id=f.id
        WHERE p.receipt_no=? AND s.matric=? AND p.amount_paid=? AND p.payment_date=?
    """, (receipt_no, matric, amount, date)).fetchone()
    conn.close()
    if p:
        result = {'valid': True, 'receipt_no': p['receipt_no'],
                  'student_name': p['fullname'], 'matric': p['matric'],
                  'department': p['department'], 'level': p['level'],
                  'fee_type': p['fee_type'],
                  'amount': f"₦{p['amount_paid']:,.0f}",
                  'date': p['payment_date'], 'verified': bool(p['verified'])}
    else:
        result = {'valid': False,
                  'message': 'Receipt not found in Kwara Poly records.'}
    return render_template('verify.html', result=result)

# ─── Public Verify (no login required) ───────────────────────────────────────
@app.route('/p/<path:receipt_no>')
def public_verify(receipt_no):
    """Public verify URL — no login needed, anyone with the link can verify"""
    conn = get_db()
    r = conn.execute("""
        SELECT p.*, s.fullname, s.matric, s.department, s.level, f.fee_type
        FROM payments p
        JOIN students s ON p.student_id=s.id
        JOIN fees f ON p.fee_id=f.id
        WHERE p.receipt_no=?
    """, (receipt_no,)).fetchone()
    conn.close()
    if r:
        result = {'valid': True, 'receipt_no': r['receipt_no'],
                  'student_name': r['fullname'], 'matric': r['matric'],
                  'department': r['department'], 'level': r['level'],
                  'fee_type': r['fee_type'],
                  'amount': f"₦{r['amount_paid']:,.0f}",
                  'date': r['payment_date'], 'verified': bool(r['verified'])}
    else:
        result = {'valid': False, 'message': 'Receipt not found in Kwara Poly records.'}
    return render_template('verify.html', result=result)

# ─── Verify QR ────────────────────────────────────────────────────────────────
@app.route('/verify', methods=['GET', 'POST'])
def verify_page():
    result = None
    if request.method == 'POST':
        receipt_id = request.form.get('receipt_id', '').strip()
        if receipt_id:
            # Direct lookup by receipt ID
            conn = get_db()
            p = conn.execute("""
                SELECT p.*, s.fullname, s.matric, s.department, s.level, f.fee_type
                FROM payments p
                JOIN students s ON p.student_id=s.id
                JOIN fees f ON p.fee_id=f.id
                WHERE p.receipt_no=?
            """, (receipt_id,)).fetchone()
            conn.close()
            if p:
                result = {'valid': True, 'receipt_no': p['receipt_no'],
                          'student_name': p['fullname'], 'matric': p['matric'],
                          'department': p['department'], 'level': p['level'],
                          'fee_type': p['fee_type'],
                          'amount': f"₦{p['amount_paid']:,.0f}",
                          'date': p['payment_date'], 'verified': bool(p['verified'])}
            else:
                result = {'valid': False, 'message': f'❌ Receipt "{receipt_id}" not found in our records. Please check the ID and try again.'}
    return render_template('verify.html', result=result)

@app.route('/verify_qr_image', methods=['POST'])
def verify_qr_image():
    if 'qr_image' not in request.files:
        return jsonify({'error': 'No image uploaded. Please select a QR photo first.'})
    f = request.files['qr_image']
    if not f or not f.filename:
        return jsonify({'error': 'No image selected.'})

    # Save with a stable, fresh tmp path
    import tempfile
    tmp_fd, tmp = tempfile.mkstemp(suffix='.png', prefix='qr_', dir=BASE_DIR)
    os.close(tmp_fd)
    try:
        f.save(tmp)
        text = ''

        # Strategy 1: zbarimg (best for most QR codes) — try multiple methods
        try:
            import subprocess
            # Decode image to PIL first, save as proper PNG (fixes JPEG/HEIC issues)
            from PIL import Image
            img = Image.open(tmp)
            # Convert to RGB and save as a clean PNG that zbarimg and pyzbar both love
            if img.mode not in ('RGB', 'L'):
                img = img.convert('RGB')
            clean = tmp + '.clean.png'
            img.save(clean, 'PNG')
            try:
                result = subprocess.run(
                    ['zbarimg', '--quiet', '--raw', clean],
                    capture_output=True, text=True, timeout=10
                )
                text = result.stdout.strip()
            except (FileNotFoundError, OSError, subprocess.TimeoutExpired):
                text = ''
            finally:
                if os.path.exists(clean):
                    os.remove(clean)
            if not text:
                # Strategy 2: pyzbar (pure Python, no subprocess)
                try:
                    from pyzbar.pyzbar import decode as pydecode
                    decoded = pydecode(Image.open(tmp))
                    if decoded:
                        text = decoded[0].data.decode('utf-8', errors='ignore')
                except Exception:
                    text = ''
        except Exception as inner_err:
            return jsonify({'error': f'Decode failed: {inner_err}'})

        if not text:
            return jsonify({'error': 'No QR code found in image. Use a clearer, well-lit photo.'})
        return jsonify({'text': text})
    finally:
        if os.path.exists(tmp):
            try: os.remove(tmp)
            except: pass

# ─── API: Student Stats ────────────────────────────────────────────────────────
@app.route('/api/student/<int:sid>/balance')
def student_balance(sid):
    conn = get_db()
    total = conn.execute("SELECT COALESCE(SUM(amount_paid),0) FROM payments WHERE student_id=?", (sid,)).fetchone()[0]
    conn.close()
    return jsonify({'total_paid': total, 'estimated_outstanding': max(0, 85000 - total)})

# ─── Fees Management ───────────────────────────────────────────────────────────
@app.route('/fees')
def fees_page():
    conn = get_db()
    fees = conn.execute("SELECT * FROM fees ORDER BY fee_type").fetchall()
    conn.close()
    return render_template('fees.html', fees=fees)

# ─── Init & Run ───────────────────────────────────────────────────────────────
init_db()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)