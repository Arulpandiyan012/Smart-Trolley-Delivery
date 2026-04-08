# Deployment Guide for ecom.thesmartedgetech.com

## Current Status
✅ **APK Updated**: Server URL configured to `https://ecom.thesmartedgetech.com`
✅ **Built Successfully**: `build/app/outputs/flutter-apk/app-debug.apk` (150.7 MB)
⏳ **Next**: Deploy backend files to your server

## What You Need to Do

### Step 1: Access Your Server via cPanel/FTP
Your server: `ecom.thesmartedgetech.com`

1. Log in to cPanel:
   ```
   https://ecom.thesmartedgetech.com:2083/
   ```
   OR
   ```
   https://thesmartedgetech.com:2083/
   ```

2. Open **File Manager** or use FTP client (Filezilla)

### Step 2: Deploy Backend Endpoint Code
**Location**: Files in `C:\Users\kamar\Downloads\`

**File**: `proof_of_delivery_endpoint.php`

**Steps**:
1. Open your **File Manager** in cPanel
2. Navigate to: `public_html/` folder
3. Find `delivery-api.php` file
4. Open in editor
5. Find line: `// 9. CHECK IF ORDER IS ALREADY RATED`
6. **PASTE the entire contents of `proof_of_delivery_endpoint.php` BEFORE this line**
7. Save file

**Expected result**: 
- `delivery-api.php` now has new action: `proof_of_delivery`
- New endpoint: `/delivery-api.php?action=proof_of_delivery`

### Step 3: Create Database Table
**File**: `proof_of_delivery_setup.php`

**Steps**:
1. Open File Manager → `public_html/`
2. **Upload** `proof_of_delivery_setup.php` to `public_html/`
3. **Visit in browser**: `https://ecom.thesmartedgetech.com/proof_of_delivery_setup.php`
4. **Should see**: 
   ```
   ✅ proof_of_deliveries table created or verified successfully!
   ```
5. **Delete the file** after running (for security)

### Step 4: Create Uploads Directory
**Path**: `public_html/uploads/proof_of_delivery/`

**Steps**:
1. File Manager → `public_html/` → Click **New Folder**
2. Create: `uploads/` (if doesn't exist)
3. Inside `uploads/`, create: `proof_of_delivery/`
4. Right-click `proof_of_delivery/` → **Permissions**
5. Set to: **755** (or 777 if 755 doesn't work)

**Result**:
```
public_html/
  ├── delivery-api.php (modified)
  └── uploads/
      └── proof_of_delivery/  ← Photos saved here
```

### Step 5: Test Server Endpoint
**Quick test** before deploying app:

1. Visit in browser:
   ```
   https://ecom.thesmartedgetech.com/delivery-api.php?action=proof_of_delivery
   ```

2. **Should see error like**:
   ```
   {"success":false,"message":"Missing required fields"}
   ```
   
   **NOT**:
   ```
   404 - File not found
   500 - Internal Server Error
   Connection timeout
   ```

### Step 6: Install New APK on Device
Once backend is deployed:

```powershell
# Uninstall old version
adb uninstall com.example.smart_trolley_delivery

# Install new APK with correct server URL
adb install -r "build/app/outputs/flutter-apk/app-debug.apk"
```

## Testing the Complete Flow

### Test 1: Happy Path (Good Internet)
1. ✅ Login to app
2. ✅ Accept delivery order
3. ✅ Click "Capture Proof & Complete Delivery"
4. ✅ Take photo
5. ✅ Click "Upload & Complete Delivery"
6. ✅ **Should see**: "Upload Successful ✓"
7. ✅ **Database**: Check that photo record created in `proof_of_deliveries` table
8. ✅ **Order status**: Should change to "delivered"

### Test 2: Offline Scenario
1. ✅ Turn off WiFi on device
2. ✅ Accept delivery
3. ✅ Capture proof
4. ✅ Click upload
5. ✅ **Should see**: "Offline Mode" dialog with "Retry" button
6. ✅ Photo saved to SQLite locally
7. ✅ Turn on WiFi
8. ✅ Reopen app
9. ✅ Check logs: `flutter logs | grep "Syncing"`
10. ✅ **Should see**: "📤 Syncing proofs: 1/1"
11. ✅ Photo uploaded automatically ✓

### Test 3: Auto-Sync
1. ✅ Capture multiple photos without internet (3-5 photos)
2. ✅ Each shows "Offline Mode" - that's normal
3. ✅ Enable internet
4. ✅ Close and reopen app
5. ✅ **Should see in logs**: "📤 Syncing proofs: 1/5", "2/5", "3/5", etc.
6. ✅ All photos upload automatically
7. ✅ Check database: All have status = 'uploaded'

## Debugging Commands

### Check Database
```sql
-- In phpMyAdmin or via SSH
SELECT * FROM proof_of_deliveries;
-- Should show: id, order_id, photo_path, upload_status, timestamp, lat, long, etc.
```

### Check Logs
```powershell
# Real-time logs
flutter logs

# Look for:
# 📤 Syncing proofs: 1/5
# ✅ Proof uploaded successfully
# ❌ Upload failed: [error message]
```

### Check Server Response
```powershell
# Test endpoint manually
$url = "https://ecom.thesmartedgetech.com/delivery-api.php?action=proof_of_delivery"
Invoke-RestMethod -Uri $url -Method POST -ContentType "multipart/form-data"
```

### Check Uploads Directory
```bash
# Via SSH
ls -la public_html/uploads/proof_of_delivery/
# Should show uploaded photos with watermarks
```

## Database Credentials
For reference (already in your backend files):
- **Database**: `u100875372_ecom`
- **User**: `u100875372_ecom`
- **Password**: `Ecom@2@25@`

## File Locations
- 📁 Backend code: `C:\Users\kamar\Downloads\proof_of_delivery_endpoint.php`
- 📁 Setup script: `C:\Users\kamar\Downloads\proof_of_delivery_setup.php`
- 📁 New APK: `build/app/outputs/flutter-apk/app-debug.apk`
- 📁 Server config: `lib/config/server_config.dart` (updated ✓)

## Server Configuration (Updated)
Your app now points to:
```dart
static const String baseUrl = 'https://ecom.thesmartedgetech.com';

// Which creates endpoints:
// POST: https://ecom.thesmartedgetech.com/delivery-api.php?action=proof_of_delivery
// GET:  https://ecom.thesmartedgetech.com/delivery-api.php?action=login
// etc.
```

## Troubleshooting

### Photos Still Not Uploading?
1. ✅ Verify `delivery-api.php` was edited (contains new code)
2. ✅ Check permissions on `/uploads/proof_of_delivery/` folder
3. ✅ Verify database table created: `SHOW TABLES LIKE 'proof_of_deliveries'`
4. ✅ Check server error logs: `public_html/error_log`

### 404 Not Found Error?
- `delivery-api.php` not in `public_html/` root
- Check file path is correct

### 413 Payload Too Large?
- Increase in `.htaccess` or `php.ini`:
```
php_value upload_max_filesize 50M
php_value post_max_size 50M
```

### Database Connection Error?
- Verify credentials in `delivery-api.php`
- Check database exists: `u100875372_ecom`

## Next: Installation & Testing

Once you've deployed backend files:

1. **Uninstall old APK**: 
   ```powershell
   adb uninstall com.example.smart_trolley_delivery
   ```

2. **Install new APK**:
   ```powershell
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```

3. **Verify in logs**:
   ```powershell
   flutter logs
   ```

4. **Test a delivery**:
   - Accept order
   - Capture proof with photo
   - Click upload
   - Should see: ✅ "Upload Successful"

5. **Check database**:
   - Photo record created
   - Order marked as "delivered"
   - File in `/uploads/proof_of_delivery/`

## Support

If something breaks, check:
1. Server logs: `public_html/error_log`
2. App logs: `flutter logs`
3. Database: `u100875372_ecom.proof_of_deliveries`
4. Permissions: `/uploads/proof_of_delivery/` should be 755 or 777

---

**Status**: 🟢 APK ready with correct server URL  
**Blocked on**: Backend deployment to your server  
**ETA to working**: 30 minutes (backend deployment + testing)
