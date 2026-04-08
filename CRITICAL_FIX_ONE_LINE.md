# CRITICAL: Fix Photos Not Uploading

## The Problem
✗ Photos are saving offline but showing: "Photo saved offline. Will sync when internet is available."
✗ Even with good internet, uploads fail silently
✗ Photos never sync automatically

## Root Cause
Your server URL in `lib/config/server_config.dart` is still a **PLACEHOLDER**:

```dart
static const String baseUrl = 'https://yourdomain.com';  // ← WRONG!
```

This domain doesn't exist, so:
1. App tries to upload to `https://yourdomain.com/delivery-api.php`
2. Request fails immediately (host unreachable)
3. Exception caught and silently logged
4. Photo marked as "pending" in database
5. User sees offline message
6. Photo stays offline forever

## Solution (5 Steps)

### Step 1: Get Your Server Domain
You need your **actual server domain**. Examples:
- `deliveryapp.com`
- `api.yourcompany.com`
- `yourdomain.in`
- IP address: `192.168.1.100` (for testing)

**Ask your server provider or check your Hostinger/cPanel URL**

### Step 2: Update server_config.dart
Open: `lib/config/server_config.dart`

Replace this line:
```dart
static const String baseUrl = 'https://yourdomain.com';
```

With your actual domain:
```dart
static const String baseUrl = 'https://deliveryapp.com';  // Replace with YOUR domain
```

**Examples for different hosting:**

**Shared Hosting (Hostinger, Bluehost, etc.)**
```dart
static const String baseUrl = 'https://yourdomain.com';
// Make sure delivery-api.php is in public_html/ root
```

**VPS/Cloud (DigitalOcean, AWS, Linode)**
```dart
static const String baseUrl = 'https://api.deliveryapp.com';
// or
static const String baseUrl = 'https://deliveryapp.com:8080';
```

**Local Testing**
```dart
static const String baseUrl = 'http://192.168.1.100:8000';
// Your machine's IP on local network
```

### Step 3: Deploy Backend Files
See file: `BACKEND_SETUP_GUIDE.md`

Quick summary:
1. Upload `proof_of_delivery_endpoint.php` code to your `delivery-api.php`
2. Run `proof_of_delivery_setup.php` to create database table
3. Create `/uploads/proof_of_delivery/` folder with permissions 755

### Step 4: Rebuild APK
After updating server URL:
```powershell
cd c:\Users\kamar\Desktop\FNP\Smart-Trolley-Delivery

flutter clean
flutter pub get
flutter build apk --debug --no-tree-shake-icons
```

APK location: `build/app/outputs/flutter-apk/app-debug.apk`

### Step 5: Reinstall & Test
```powershell
# Uninstall old app
adb uninstall com.example.smart_trolley_delivery

# Install new APK
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Test upload
# 1. Accept delivery
# 2. Click "Capture Proof & Complete Delivery"
# 3. Take photo
# 4. Click "Upload & Complete Delivery"
# 5. Should show: "Upload Successful" ✓
```

## Verify Fix

### Check 1: DNS Resolution
Test if your domain resolves:
```powershell
# Windows
nslookup yourdomain.com

# Should show IP address, NOT error
```

### Check 2: Server Reachability
Test from phone (ADB):
```powershell
adb shell curl -v https://yourdomain.com/delivery-api.php
```

Should return your PHP page, not 404 or timeout.

### Check 3: Backend Endpoint
Visit in browser:
```
https://yourdomain.com/delivery-api.php?action=proof_of_delivery
```

Should show error like:
```
Missing required fields: order_id, photo
```

NOT:
```
File not found (404)
500 Internal Server Error
Connection timeout
```

### Check 4: Database Table
In phpMyAdmin:
- Database: `u100875372_ecom`
- Table: `proof_of_deliveries` should exist
- Has columns: id, order_id, photo_path, upload_status, etc.

### Check 5: Upload Directory
Test file upload permission:
```
/uploads/proof_of_delivery/  ← Directory exists
                             ← Writable (chmod 755 or 777)
```

## What Happens After Fix

1. ✅ User captures photo with GPS/timestamp
2. ✅ App sends to your server immediately
3. ✅ Server saves photo to `/uploads/proof_of_delivery/`
4. ✅ Server creates database record
5. ✅ Server responds with success
6. ✅ App updates order to "delivered"
7. ✅ Photo never lost

## If Still Not Working

### Symptom: "Connection timeout"
- Server domain unreachable
- **Fix**: Check domain is correct, verify server is running

### Symptom: "404 Not Found"
- delivery-api.php doesn't exist at that path
- **Fix**: Upload file to correct location, check path in config

### Symptom: "413 Payload Too Large"
- Server limit on file upload
- **Fix**: Increase PHP `upload_max_filesize` to at least 10MB

### Symptom: "Permission Denied" writing photo
- `/uploads/proof_of_delivery/` folder not writable
- **Fix**: Set permissions to 755 or 777

### Symptom: "Unknown action"
- Backend endpoint code not added to delivery-api.php
- **Fix**: Copy code from `proof_of_delivery_endpoint.php` into your file

## Debug Logging

After rebuild, check debug logs:
```powershell
flutter logs
```

Look for:
```
📤 Uploading proof with timestamp: 2026-04-08T10:30:45Z
📍 Location: 37.7749°N, -122.4194°W
✅ Proof uploaded successfully
✓ Order status updated to: delivered
```

If you see errors instead:
```
❌ Upload failed: Connection timeout
❌ Server error: 404
❌ File permission denied
```

Copy full error and check troubleshooting above.

## TL;DR

**The entire issue is one line of code:**

```dart
// WRONG:
static const String baseUrl = 'https://yourdomain.com';

// CORRECT:
static const String baseUrl = 'https://yourrealdomain.com';  // Put YOUR domain here!
```

Find and replace that ONE line, rebuild APK, reinstall.

**Done.** ✓

---

## Files Location Reference
- 📁 `lib/config/server_config.dart` - Update baseUrl here
- 📁 `BACKEND_SETUP_GUIDE.md` - How to deploy backend
- 📁 `OFFLINE_SYNC_AND_RETRY_GUIDE.md` - How auto-sync works
- 📁 `build/app/outputs/flutter-apk/app-debug.apk` - APK to install

## Next Action
👉 **Reply with your actual server domain (e.g., deliveryapp.com)**

Then I will:
1. Update server_config.dart automatically
2. Provide exact backend deployment instructions
3. Create database setup script
4. Rebuild APK
5. Test the entire flow
