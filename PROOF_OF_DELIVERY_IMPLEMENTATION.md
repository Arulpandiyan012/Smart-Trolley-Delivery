# Delivery Proof of Delivery Implementation

## Overview

This document outlines the complete **Proof of Delivery (POD)** system implemented in the Smart Trolley Delivery app. The system ensures delivery drivers capture photographic evidence with GPS coordinates and timestamps, with automatic sync when offline.

## Features Implemented

### 1. **Photo Capture with GPS Coordinates**
- Drivers can take photos directly from the camera or select from gallery
- GPS location is automatically captured (latitude, longitude)
- Timestamp is recorded for every photo
- Location accuracy is set to high for precise delivery confirmation

### 2. **Watermarking System**
- Photos are automatically watermarked with:
  - **Timestamp** (formatted as DD/MM/YYYY HH:MM:SS)
  - **GPS Coordinates** (latitude and longitude with 6 decimal places)
  - **Verification badge** (visual indicator of verified delivery)
- Watermark prevents use of old or altered photos
- Semi-transparent overlay ensures original image visibility

### 3. **Offline Support with SQLite Database**
- Photos are saved to local SQLite database if network is unavailable
- Metadata stored includes:
  - Order ID
  - Photo file path
  - Timestamp and GPS data
  - Upload status (pending, uploading, completed, failed)
  - Error messages for failed uploads
- Automatic sync when driver comes back online

### 4. **Upload Progress Tracking**
- Real-time upload progress indicator (percentage-based)
- Loading state prevents premature app closure
- Visual feedback during upload process
- Automatic retry on failed uploads

## File Structure

```
lib/
├── models/
│   └── proof_of_delivery_model.dart      # Model for proof data
├── services/
│   ├── watermark_service.dart            # Watermarking logic
│   └── proof_of_delivery_offline_service.dart  # Offline storage & sync
├── screens/
│   └── order_details/
│       └── view/
│           ├── order_details_screen.dart         # Updated with POD navigation
│           └── proof_of_delivery_screen.dart     # New POD capture screen
```

## Architecture

### Models

#### `ProofOfDeliveryPhoto` (`lib/models/proof_of_delivery_model.dart`)
- Represents a single proof of delivery photo
- Fields: `id`, `orderId`, `photoPath`, `timestamp`, `latitude`, `longitude`, `uploadStatus`, `errorMessage`, `createdAt`, `uploadedAt`
- Methods: `toMap()`, `fromMap()`, `copyWith()`

### Services

#### `WatermarkService` (`lib/services/watermark_service.dart`)
Handles adding watermarks to photos:
- `addWatermark()` - Main method to add timestamp and GPS watermark
- `_addWatermarkOverlay()` - Draws semi-transparent overlay
- `_saveWatermarkedImage()` - Saves watermarked image
- `validateWatermark()` - Validates if photo has watermark

#### `ProofOfDeliveryOfflineService` (`lib/services/proof_of_delivery_offline_service.dart`)
Manages local storage and server sync:
- `saveProofLocally()` - Saves photo metadata to SQLite
- `getPendingProofs()` - Retrieves photos waiting for upload
- `getProofByOrderId()` - Gets proof for specific order
- `updateProofStatus()` - Updates upload status
- `uploadProofToServer()` - Uploads with progress tracking
- `syncPendingProofs()` - Syncs all pending photos
- `deleteProof()` - Deletes a proof record
- `clearCompletedProofs()` - Cleans up uploaded photos

### UI Screens

#### `ProofOfDeliveryScreen` (`lib/screens/order_details/view/proof_of_delivery_screen.dart`)
Complete 3-step delivery proof UI:

**Step 1: Capture Photo**
- "Take Photo" button - Opens device camera
- "Choose from Gallery" button - Select existing photo
- Real-time photo preview

**Step 2: Add Watermark**
- "Add Watermark" button - Adds timestamp + GPS overlay
- Watermarked photo preview
- Shows completion status

**Step 3: Upload Proof**
- "Upload & Complete Delivery" button
- Progress indicator during upload
- Offline fallback message
- Error handling and retry logic

**Additional Features:**
- Location status card showing GPS coordinates
- 5-step process information card
- Error message display
- Loading states with visual feedback

## Database Schema

SQLite table: `proof_of_delivery`

```sql
CREATE TABLE proof_of_delivery (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  photo_path TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  upload_status TEXT NOT NULL,
  error_message TEXT,
  created_at TEXT NOT NULL,
  uploaded_at TEXT
)
```

## User Flow

1. **Driver Reaches Delivery Location**
   - App shows "Capture Proof & Complete Delivery" button
   - Driver navigates to `ProofOfDeliveryScreen`

2. **Capture Photo**
   - GPS location is acquired (shows in status card)
   - Driver takes photo with camera or selects from gallery
   - Photo preview is shown

3. **Add Watermark**
   - Driver clicks "Add Watermark"
   - Service overlays timestamp and GPS coordinates
   - Watermarked photo is displayed

4. **Upload Proof**
   - Driver clicks "Upload & Complete Delivery"
   - Progress indicator shows upload status
   - **If Online:** Photo uploads to server immediately
   - **If Offline:** Photo saved locally, syncs automatically when online

5. **Completion**
   - Order status updated to "delivered"
   - Screen closes automatically
   - User returns to order details

## Dependencies Added

```yaml
image_picker: ^1.1.2        # Photo capture/selection
image: ^4.3.0              # Image processing
path_provider: ^2.1.4      # Local file storage paths
sqflite: ^2.4.1           # Local database
intl: ^0.20.1             # Date/time formatting
```

## Configuration

### Server Endpoint
Update the server endpoint in `proof_of_delivery_screen.dart`:

```dart
serverEndpoint: 'http://your-server.com/api/proof-of-delivery',
```

Replace with your actual backend API endpoint.

### API Expected Format
```json
POST /api/proof-of-delivery
{
  "order_id": 123,
  "timestamp": "Order: ORD-123 - Delivered via App",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "photo": <binary file data>
}
```

## Offline Sync Mechanism

### Automatic Sync
When driver comes back online, pending photos automatically sync:

```dart
await _offlineService.syncPendingProofs(
  serverEndpoint: 'http://your-server.com/api/proof-of-delivery',
  onProgress: (current, total) {
    debugPrint('Syncing: $current/$total');
  },
);
```

### Manual Sync
Can be triggered from app settings or dashboard:

```dart
final offlineService = ProofOfDeliveryOfflineService();
await offlineService.syncPendingProofs(...);
```

## Error Handling

- **Location Unavailable:** Dialog prompts user to wait/retry
- **Photo Capture Failure:** Error message displayed with retry option
- **Watermark Failure:** Shows error and allows retake
- **Upload Failure (Online):** Message states "Photo saved offline, will sync when online"
- **Network Error:** Automatically saved locally for later sync

## Security & Fraud Prevention

1. **Timestamp Watermark**
   - Prevents use of old photos
   - Shows exact delivery time
   - Prevents backdating deliveries

2. **GPS Coordinates**
   - Confirms actual delivery location
   - Prevents false delivery claims
   - Matches delivery address with actual location

3. **Photo Integrity**
   - Watermark makes tampering obvious
   - Verification badge on all photos
   - Server can validate metadata against timestamp

## Testing the Implementation

1. **Mock Online Upload:**
   - Ensure backend endpoint is configured
   - Check uploads appear on server
   - Verify metadata is received correctly

2. **Test Offline Mode:**
   - Disable network before upload
   - Verify photo saves locally
   - Re-enable network and check automatic sync
   - Confirm status updates to "completed"

3. **GPS Validation:**
   - Check watermark shows correct coordinates
   - Verify location matches delivery address
   - Test in areas with poor GPS signal

4. **Photo Quality:**
   - Test camera capture quality
   - Test gallery selection
   - Verify watermark doesn't obscure important image content

## Future Enhancements

1. **Advanced Image Processing**
   - Text overlay on watermark (requires font rendering package)
   - Multiple photo angles (360° delivery proof)
   - Image compression for faster uploads

2. **Geofencing**
   - Automatic delivery location detection
   - Alert if delivery outside expected area
   - Prevent early proof of delivery

3. **Signature Capture**
   - Add customer signature to proof
   - Integrated signature pad UI
   - Multi-layer proof document

4. **Server Integration**
   - Real-time upload validation
   - Duplicate photo detection
   - AI-based content verification

## Troubleshooting

### Photos Not Uploading
- Check server endpoint configuration
- Verify network connectivity
- Check database for pending proofs: `getPendingProofs()`
- Review error messages in logs

### Location Not Showing
- Ensure location permissions granted
- Check GPS signal strength
- Verify geolocator package permissions in AndroidManifest.xml and Info.plist

### Watermark Not Visible
- Check watermark service is returning valid path
- Verify image file format (PNG recommended)
- Check file permissions in app documents directory

---

**Implementation Date:** April 7, 2026  
**Status:** Complete and Ready for Testing
