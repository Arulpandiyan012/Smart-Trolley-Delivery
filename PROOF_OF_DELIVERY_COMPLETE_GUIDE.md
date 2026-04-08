# Complete Proof of Delivery Backend Integration

## ✅ What Was Done

### 1. Backend Files Created (In Downloads)
- ✅ `proof_of_delivery_endpoint.php` - The PHP endpoint code
- ✅ `proof_of_delivery_setup.php` - Database table creator
- ✅ `delivery-api.php.backup` - Backup of original file
- ✅ `INTEGRATION_STEPS.md` - Complete integration guide

### 2. Flutter App Updated
- ✅ Created `lib/config/server_config.dart` - Centralized server configuration
- ✅ Updated `proof_of_delivery_screen.dart` - Now uses ServerConfig
- ✅ All code compiles without errors

## 📋 Integration Checklist

### Step 1: Backend Setup (Your Server)
- [ ] Copy `proof_of_delivery_endpoint.php` content into your `delivery-api.php` file
  - Find line: `// 9. CHECK IF ORDER IS ALREADY RATED`
  - Insert code just BEFORE that line
  
- [ ] Run database setup (choose ONE option):
  - Option A: Upload `proof_of_delivery_setup.php` and visit it on your server
  - Option B: Copy the SQL from `INTEGRATION_STEPS.md` and run in phpMyAdmin
  
- [ ] Create uploads directory:
  ```
  /public_html/uploads/proof_of_delivery/
  ```
  Set permissions to 755

### Step 2: Configure Flutter App
- [ ] Edit `lib/config/server_config.dart`
- [ ] Replace this line:
  ```dart
  static const String baseUrl = 'https://yourdomain.com';
  ```
  With your actual domain:
  ```dart
  static const String baseUrl = 'https://yourcompany.com';
  ```

### Step 3: Build APK
```powershell
flutter clean
flutter pub get
flutter build apk --debug --no-tree-shake-icons
```

### Step 4: Test
1. Install APK on device/emulator
2. Login with delivery credentials
3. Accept an order
4. Click "Capture Proof & Complete Delivery"
5. Take a photo with watermark
6. Tap "Upload & Complete Delivery"
7. Should see: "Proof of delivery uploaded successfully"

## 🔧 Backend File Details

### proof_of_delivery_endpoint.php
**What it does:**
- Receives photo uploads from Flutter app
- Stores watermarked photos in `/uploads/proof_of_delivery/`
- Records GPS coordinates and timestamp
- Updates order status to "delivered"
- Returns success/error response

**Key features:**
- Validates delivery token
- Creates upload directory if missing
- Handles file uploads safely
- Updates existing proofs if re-uploaded
- Logs all operations to `delivery_api.log`

### proof_of_delivery_setup.php
**What it does:**
- Creates `proof_of_deliveries` table if missing
- Creates uploads directory structure
- Shows table structure verification

**Run it by:**
- Uploading to server
- Visiting: `https://yourdomain.com/proof_of_delivery_setup.php`

## 📊 Database Schema

```sql
CREATE TABLE proof_of_deliveries (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT (links to orders table),
    delivery_boy_id INT (links to delivery_boys table),
    photo_path VARCHAR(500) (server file path),
    photo_data LONGBLOB (binary photo data),
    timestamp VARCHAR(255) (delivery time),
    latitude DECIMAL(10,8) (GPS coordinate),
    longitude DECIMAL(11,8) (GPS coordinate),
    upload_status VARCHAR(50) (default: 'uploaded'),
    error_message TEXT (error details if failed),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
```

## 🔌 API Endpoint

**URL:**
```
https://yourdomain.com/delivery-api.php?action=proof_of_delivery
```

**Method:** POST

**Parameters:**
```
order_id (required): integer - Order ID
token (required): string - Delivery boy auth token
latitude (optional): float - GPS latitude
longitude (optional): float - GPS longitude  
timestamp (optional): string - Delivery timestamp
photo (file): multipart form data - JPG/PNG photo
```

**Response Success:**
```json
{
    "success": true,
    "message": "Proof of delivery uploaded successfully",
    "proof_id": 123,
    "version": "1.0.4"
}
```

**Response Failure:**
```json
{
    "success": false,
    "message": "Invalid token",
    "version": "1.0.4"
}
```

## 📱 Flutter App Flow

1. Driver taps "Capture Proof & Complete Delivery"
2. ProofOfDeliveryScreen opens
3. GPS location acquired automatically
4. Driver takes photo or selects from gallery
5. WatermarkService adds:
   - Timestamp
   - GPS coordinates
   - Order number
6. Driver taps "Upload & Complete Delivery"
7. App calls `ServerConfig.proofOfDeliveryUrl`
8. Backend receives, saves photo, updates order status
9. Order marked as "delivered"
10. Dashboard refreshes

## ⚙️ Configuration Steps

### In server_config.dart
```dart
class ServerConfig {
  // UPDATE THIS with your domain
  static const String baseUrl = 'https://yourdomain.com';
  
  // Rest stays the same
  static const String deliveryApiPath = '/delivery-api.php';
  static String get proofOfDeliveryUrl =>
      '$baseUrl$deliveryApiPath?action=proof_of_delivery';
}
```

### Examples:
```dart
// For localhost/testing
static const String baseUrl = 'http://localhost:8000';

// For production
static const String baseUrl = 'https://ecommerce.com';

// For subdomain
static const String baseUrl = 'https://api.ecommerce.com';
```

## 🧪 Testing with cURL

```bash
curl -X POST "https://yourdomain.com/delivery-api.php?action=proof_of_delivery" \
  -H "Content-Type: multipart/form-data" \
  -F "order_id=123" \
  -F "token=abc123token" \
  -F "latitude=13.0827" \
  -F "longitude=80.2707" \
  -F "timestamp=2026-04-07 18:30:00" \
  -F "photo=@/path/to/photo.jpg"
```

## 📁 File Locations

### Your Server
```
/public_html/
├── delivery-api.php (UPDATED with proof_of_delivery endpoint)
├── setup_delivery_db.php
├── tracking-api.php
└── uploads/
    └── proof_of_delivery/ (CREATE THIS FOLDER)
        ├── 1712521800_abc123.jpg
        ├── 1712521900_def456.jpg
        └── ... (proof photos)
```

### Flutter App
```
lib/
├── config/
│   └── server_config.dart (NEW - EDIT THIS)
├── screens/
│   └── order_details/
│       └── view/
│           └── proof_of_delivery_screen.dart (UPDATED)
└── services/
    ├── proof_of_delivery_offline_service.dart
    └── watermark_service.dart
```

## ✔️ Verification Checklist

After integration, verify:

1. **Database:**
   - [ ] `proof_of_deliveries` table exists
   - [ ] Can see table in phpMyAdmin

2. **Files:**
   - [ ] `delivery-api.php` updated with endpoint
   - [ ] `/uploads/proof_of_delivery/` folder exists
   - [ ] Has write permissions (755 or 777)

3. **Configuration:**
   - [ ] `server_config.dart` has correct domain
   - [ ] Base URL doesn't have trailing slash

4. **Testing:**
   - [ ] cURL request returns success
   - [ ] Photo file saved in uploads folder
   - [ ] Database record created
   - [ ] Order status changed to "delivered"

## 🐛 Troubleshooting

### "Photo saved locally. Will sync when internet is available"
- Backend URL is wrong or server unreachable
- Check `server_config.dart` baseUrl
- Test with cURL first

### "Failed to upload"
- Check uploads directory permissions
- Verify `/uploads/proof_of_delivery/` exists
- Check file size (should be < 10MB)

### "Invalid token"
- Delivery boy token expired
- Need to re-login to get fresh token

### "Database error"
- Run `proof_of_delivery_setup.php`
- Or manually create table using SQL

### "Table doesn't exist"
- Visit `proof_of_delivery_setup.php` on your server
- Or run SQL script in phpMyAdmin

## 📞 Support Files

All integration guides are in Downloads:
- `INTEGRATION_STEPS.md` - Step-by-step integration
- `BACKEND_SETUP_GUIDE.md` - Backend setup details
- `proof_of_delivery_endpoint.php` - Copy this into delivery-api.php
- `proof_of_delivery_setup.php` - Run this on server

## 🚀 Next Steps

1. **Update `delivery-api.php`** with endpoint code
2. **Run database setup** script
3. **Create uploads folder** with write permissions
4. **Configure Flutter** app with your domain
5. **Build APK** and test

---

**Status:** ✅ All files ready. Follow the integration steps above to complete the setup.

