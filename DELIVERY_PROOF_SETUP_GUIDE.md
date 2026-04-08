# Quick Setup Guide - Proof of Delivery Feature

## What Was Implemented

A complete delivery proof capture system that requires drivers to:
1. ✅ Capture a photo when they reach delivery location
2. ✅ Add watermark with timestamp and GPS coordinates
3. ✅ Upload proof to server with offline fallback
4. ✅ Sync automatically when back online

## Step 1: Get Dependencies

Run this command to fetch all required packages:

```bash
flutter pub get
```

This will install:
- `image_picker: ^1.1.2` - Photo capture
- `image: ^4.3.0` - Image processing
- `path_provider: ^2.1.4` - Storage paths
- `sqflite: ^2.4.1` - Local database
- `intl: ^0.20.1` - Date formatting

## Step 2: Update Server Endpoint

Open `lib/screens/order_details/view/proof_of_delivery_screen.dart`

Find line ~215 and update:
```dart
serverEndpoint: 'http://your-server.com/api/proof-of-delivery',
```

Replace with your actual backend API endpoint.

## Step 3: Configure Permissions

### Android (android/app/src/main/AndroidManifest.xml)

Add these permissions:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### iOS (ios/Runner/Info.plist)

Add these keys:
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to capture delivery proof photos</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to record GPS coordinates on delivery proof</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need to access your photos to select delivery proof images</string>
</thinking>
```

## Step 4: Test the Feature

### On Device/Emulator

1. Run the app:
```bash
flutter run
```

2. Navigate to order details
3. When order status is "picked_up", you'll see: **"Capture Proof & Complete Delivery"** button
4. Click the button to open proof of delivery screen

### Test Offline Mode

1. Disable WiFi/Mobile data before upload
2. Take photo and click "Upload & Complete Delivery"
3. Photo saves locally with message: "Photo saved offline and will sync when you are back online"
4. Enable WiFi/Mobile data
5. Photos automatically sync to server

## File Locations

| File | Purpose |
|------|---------|
| `lib/models/proof_of_delivery_model.dart` | Data model for photos |
| `lib/services/watermark_service.dart` | Watermark generation |
| `lib/services/proof_of_delivery_offline_service.dart` | Database & sync |
| `lib/screens/order_details/view/proof_of_delivery_screen.dart` | UI screen |
| `lib/screens/order_details/view/order_details_screen.dart` | Updated with POD button |
| `pubspec.yaml` | Added dependencies |

## API Endpoint Format

Your server should accept:
```
POST /api/proof-of-delivery
Content-Type: multipart/form-data

Fields:
- order_id (integer)
- timestamp (string)
- latitude (float)
- longitude (float)
- photo (file)
```

Expected responses:
- **200/201:** Upload successful
- **Any other code:** Upload failed (saved locally for retry)

## Database Location

Local SQLite database stored at:
```
<app-documents-directory>/proof_of_delivery.db
```

Table: `proof_of_delivery`

## Debugging

### View Pending Proofs
```dart
final service = ProofOfDeliveryOfflineService();
final pending = await service.getPendingProofs();
for (var proof in pending) {
  print('Order ${proof.orderId}: ${proof.uploadStatus}');
}
```

### Check Logs
All operations log with emojis:
- ✅ Success operations
- ❌ Error operations
- 📍 Location operations
- 💾 Database operations
- 🔄 Sync operations

## Features at a Glance

```
Delivery Proof Screen
├─ Step 1: Capture Photo
│  ├─ Take Photo (Camera)
│  └─ Choose from Gallery
│
├─ Step 2: Add Watermark
│  ├─ GPS Location Card
│  └─ Add Watermark Button
│
└─ Step 3: Upload Proof
   ├─ Upload Progress Bar
   └─ Automatic Offline Sync
```

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Location not showing | Wait 5-10 seconds for GPS to acquire |
| Photos not uploading | Check server endpoint is correct |
| Camera not opening | Verify permissions in AndroidManifest.xml/Info.plist |
| Offline photos not syncing | Check network status and manually retry |

## What Happens During Delivery

1. **Driver at delivery location**
   - "Capture Proof & Complete Delivery" button visible

2. **Driver takes/selects photo**
   - GPS location automatically captured
   - Photo preview shown

3. **Driver adds watermark**
   - Timestamp + GPS coordinates embedded
   - Visual verification badge added

4. **Driver uploads proof**
   - If online: Uploads immediately
   - If offline: Saves locally, syncs when online
   - Progress bar shows upload status

5. **Completion**
   - Order status changes to "delivered"
   - Proof saved in database
   - Driver can proceed to next delivery

---

**Ready to Test!** 🚀

Run `flutter pub get` then `flutter run` to start testing the delivery proof feature.
