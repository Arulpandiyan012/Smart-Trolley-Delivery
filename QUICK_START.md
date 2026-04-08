# ⚡ QUICK START: Proof Upload Fix

## ✅ DONE - Server URL Updated
```
Server: https://ecom.thesmartedgetech.com
APK Built: build/app/outputs/flutter-apk/app-debug.apk (150.7 MB)
```

## 📋 TODO (4 Steps)

### 1️⃣ Deploy Backend Code (5 minutes)
**File**: `C:\Users\kamar\Downloads\proof_of_delivery_endpoint.php`

In cPanel File Manager:
1. Open `public_html/delivery-api.php`
2. Find line: `// 9. CHECK IF ORDER IS ALREADY RATED`
3. Paste entire `proof_of_delivery_endpoint.php` code BEFORE this line
4. Save

### 2️⃣ Create Database Table (1 minute)
**File**: `C:\Users\kamar\Downloads\proof_of_delivery_setup.php`

1. Upload to `public_html/`
2. Visit: `https://ecom.thesmartedgetech.com/proof_of_delivery_setup.php`
3. Should see: ✅ `proof_of_deliveries table created`
4. Delete the file

### 3️⃣ Create Uploads Folder (1 minute)
In cPanel File Manager:
1. Go to `public_html/uploads/proof_of_delivery/`
2. Set permissions to **755** (or 777)
3. Test: Folder exists and is writable

### 4️⃣ Install & Test (5 minutes)
```powershell
# Uninstall old
adb uninstall com.example.smart_trolley_delivery

# Install new
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Test: Capture photo → Upload → Should succeed ✓
```

## 🧪 Quick Test
```powershell
# Should return error about missing fields (not 404)
curl https://ecom.thesmartedgetech.com/delivery-api.php?action=proof_of_delivery
```

## 📍 Key Files
- 📁 Backend: `C:\Users\kamar\Downloads\proof_of_delivery_endpoint.php`
- 📁 Setup: `C:\Users\kamar\Downloads\proof_of_delivery_setup.php`
- 📁 New APK: `build\app\outputs\flutter-apk\app-debug.apk`
- 📋 Full Guide: `DEPLOYMENT_FOR_ECOM_GUIDE.md`

## 🎯 Expected Result
✅ Users capture photo → uploads immediately  
✅ If offline → saves locally → auto-syncs when online  
✅ Order marked "delivered" → customer notified  

**Time to completion: ~15 minutes**
