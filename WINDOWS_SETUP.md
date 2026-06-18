# 🪟 Windows Setup (One-Click)

## Option 1: Run with Python installed (Recommended)

### Step 1: Download the project
Click the green **"Code"** button on GitHub → **"Download ZIP"**
Extract the ZIP file to your Desktop or any folder

### Step 2: Double-click
```
setup-and-run.bat
```

That's it! ✅ The batch file will:
- Check Python is installed
- Install required packages automatically
- Open the app in your browser
- Show login: `admin` / `admin123`

---

## Option 2: Manual Setup

If the batch file doesn't work:

### 1. Install Python
Download from: https://www.python.org/downloads/
**Must check:** ✅ "Add Python to PATH" during install

### 2. Open Command Prompt
Press `Win + R` → type `cmd` → Enter

### 3. Go to the project folder
```cmd
cd Desktop\kwara-poly-fees-system-main
```

### 4. Install packages
```cmd
pip install flask qrcode[pil] pyzbar
```

### 5. Install QR scanner
Download from: https://zbar.sourceforge.net/

### 6. Run
```cmd
python app.py
```

### 7. Open browser
```
http://localhost:5000
```

---

## Login Details
| Field | Value |
|-------|-------|
| Username | `admin` |
| Password | `admin123` |

---

## Troubleshooting

**"pip not found"** → Reinstall Python and check "Add to PATH"

**"zbar not found"** → Download and install: https://zbar.sourceforge.net/

**Port 5000 in use** → Change port in `app.py` line ~200:
```python
app.run(host='0.0.0.0', port=5001, debug=True)
```
Then open `http://localhost:5001`

---

## Changing the Default Password
Edit `database.py` → find `admin123` → change to your preferred password, then delete `kwara_fees.db` and run again.