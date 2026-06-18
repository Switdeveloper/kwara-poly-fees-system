# 🏫 Kwara Poly Fees System
### Offline School Fees Recording & Verification System with QR Code

> A fully offline student fees management system for **Kwara State Polytechnic**. Records payments, generates QR receipt codes, and allows students/parents to verify payments by scanning the QR — no internet required after setup.

---

## ✨ Features

- ✅ **Offline-first** — runs entirely on your local network, no internet needed
- 👥 **Student Management** — add/search students by matric, name, or department
- 💰 **Payment Recording** — record fees with live student search
- 🧾 **QR Receipt Generation** — every payment gets a unique QR code receipt
- 📷 **QR Scanning** — verify payments by uploading a QR image or pasting data
- 🖨️ **Printable Receipts** — print receipts directly from the browser
- 📊 **Dashboard** — live stats: total students, daily collections, recent payments
- 🔐 **Admin Login** — secured with password hashing
- 🗄️ **SQLite Database** — zero setup, zero dependencies

---

## 🛠️ Tech Stack

- **Backend:** Python 3 + Flask
- **Database:** SQLite (local file)
- **QR Generation:** qrcode (Python)
- **QR Scanning:** zbarimg + pyzbar
- **Frontend:** Bootstrap 5 + vanilla JS

---

## 🚀 Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/Switdeveloper/kwara-poly-fees-system.git
cd kwara-poly-fees-system

# 2. Run the app
python3 app.py

# 3. Open your browser
http://localhost:5000

# 4. Login
# Username: admin
# Password: admin123
```

---

## 📋 How It Works

### For Admin:
1. Login → Dashboard
2. Add students (Name, Matric, Department, Level)
3. Go to **Record Payment** → search student → select fee type → record
4. Receipt with QR code is generated automatically
5. Print or screenshot the receipt to give to student

### For Student/Parent:
1. Go to **Verify Payment** (`/verify`)
2. Upload a photo/screenshot of the QR code OR paste the QR text
3. System shows: ✅ VERIFIED + full payment details
4. If receipt is fake/tampered → ❌ INVALID

---

## 🔐 Default Login

| Username | Password |
|----------|----------|
| admin    | admin123 |

> ⚠️ Change the default password in `database.py` before deploying.

---

## 📁 Project Structure

```
kwara_poly_fees_system/
├── app.py              ← Flask app (main)
├── database.py         ← SQLite setup & models
├── kwara_fees.db       ← SQLite database (auto-created)
├── test_qr.png         ← Sample QR for testing
├── templates/
│   ├── base.html       ← Layout template
│   ├── login.html      ← Admin login
│   ├── dashboard.html  ← Stats & recent payments
│   ├── students.html   ← Student list & add form
│   ├── record_payment.html ← Payment recording
│   ├── receipt.html    ← Receipt with QR code
│   ├── verify.html     ← QR scanning & verification
│   └── payments.html   ← All payments list
└── static/
```

---

## 📷 Screenshots

**Receipt with QR Code:**
```
┌──────────────────────────────┐
│  KWARA STATE POLYTECHNIC     │
│  Payment Receipt             │
│                              │
│  Receipt: KWP/000001         │
│  ─────────────────────────   │
│  Student: John Doe           │
│  Matric: 2024/CS/001         │
│  Fee: School Fees            │
│  Amount: ₦85,000            │
│  Date: 2025-06-18           │
│  ─────────────────────────   │
│        [QR CODE]             │
│  ─────────────────────────   │
│  Scan to verify payment      │
└──────────────────────────────┘
```

---

## 📜 License

MIT License — Free to use and modify.

---

Built for **Kwara State Polytechnic** 🏫