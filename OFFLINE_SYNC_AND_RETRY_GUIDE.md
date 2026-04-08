# Offline Sync & Auto-Retry Implementation Guide

## Overview

The proof of delivery system now has enhanced offline handling with automatic retry when the app comes back online. When photos fail to upload due to network issues, they are stored locally and automatically synced when connectivity is restored.

## What Changed

### 1. **Enhanced Upload Dialog** 
📁 File: `lib/screens/order_details/view/proof_of_delivery_screen.dart`

When upload fails, users now see a dialog with two options:
- **Later**: Dismiss and leave photo saved offline
- **Retry**: Try uploading again immediately

```
┌─────────────────────────────┐
│      Offline Mode           │
├─────────────────────────────┤
│ Photo saved offline and     │
│ will sync automatically     │
│ when you are back online.   │
│                             │
│ Tap "Retry" to try          │
│ uploading again now.        │
├─────────────────────────────┤
│  [Later]      [Retry] ✓    │
└─────────────────────────────┘
```

### 2. **App Lifecycle Management**
📁 File: `lib/main.dart`

Added `_AppLifecycleObserver` that monitors app state:
- When user returns to app (resume state)
- Automatically syncs all pending photos
- Logs progress: "Syncing proofs: 1/5"
- Shows debug logs for troubleshooting

### 3. **Automatic Offline Service Initialization**
📁 File: `lib/main.dart`

ProofOfDeliveryOfflineService now initializes when app launches:
```dart
void main() async {
  // ...
  ProofOfDeliveryOfflineService();  // Initialize at startup
  runApp(const DeliveryApp());
}
```

## How It Works

### Scenario 1: Good Internet
1. User captures photo
2. App gets GPS location
3. Watermark added
4. Photo uploaded immediately ✅
5. Order marked as "delivered"

### Scenario 2: No Internet
1. User captures photo
2. App attempts upload
3. **Upload fails** (no network)
4. Photo saved locally to SQLite
5. Dialog shows: "Offline Mode - Will sync automatically"
6. Order status NOT changed yet

### Scenario 3: Internet Returns
1. User opens app again
2. System detects resumed state
3. **Auto-sync triggers** 🔄
4. All pending photos upload
5. Order updated to "delivered"
6. Debug log shows: "📤 Syncing proofs: 1/5"

## Database Status Tracking

Photos are tracked with upload status:

| Status | Meaning | Action |
|--------|---------|--------|
| `pending` | Not yet uploaded | Will sync automatically |
| `failed` | Upload error | Will retry on resume |
| `uploaded` | Success | Removed from sync queue |

## Implementation Details

### Offline Service Flow
```
User captures photo
        ↓
[GPS + Watermark] 
        ↓
Try upload to server
        ↓
      ✗ FAIL
        ↓
Save to SQLite with status='pending'
        ↓
Show "Offline Mode" dialog
        ↓
User presses "Retry" OR closes app
        ↓
[App later resumes]
        ↓
didChangeAppLifecycleState(resumed)
        ↓
syncPendingProofs() runs automatically
        ↓
All photos uploaded successfully
        ↓
Status updated to 'uploaded'
```

### Progress Logging
The system logs detailed progress:
```
🔄 App resumed - syncing pending proofs...
📤 Syncing proofs: 1/5
📤 Syncing proofs: 2/5
✅ Proof uploaded successfully
📤 Syncing proofs: 3/5
✅ Proof uploaded successfully
...
ℹ️ No pending proofs to sync
```

## Testing the Feature

### Test Case 1: Manual Retry
1. Turn off internet
2. Capture proof of delivery
3. Click upload
4. See "Offline Mode" dialog
5. Click "Retry" button
6. Should fail again (no internet)
7. Turn on internet
8. Click "Retry" again
9. Should upload successfully ✓

### Test Case 2: Auto-Sync on Resume
1. Capture proof (no internet)
2. Photo saves offline
3. Close app
4. Turn on internet
5. Reopen app
6. Should auto-sync immediately ✓
7. Check logs: "Syncing proofs: 1/N"

### Test Case 3: Multiple Pending Photos
1. Turn off internet
2. Capture 3 photos
3. Each fails but saves offline
4. Close app
5. Turn on internet  
6. Reopen app
7. Should see: "Syncing proofs: 1/3", "2/3", "3/3"
8. All upload successfully ✓

## Configuration

### Server URL
📁 File: `lib/config/server_config.dart`

**IMPORTANT:** Replace placeholder with your actual server:
```dart
static const String baseUrl = 'https://yourdomain.com';  // ← UPDATE THIS
```

Examples:
```dart
// Hostinger/Bluehost shared hosting
static const String baseUrl = 'https://deliveryapp.com';

// Your server with SSL
static const String baseUrl = 'https://api.deliverycompany.com';

// Local testing
static const String baseUrl = 'http://192.168.1.100:8000';
```

### Proof Endpoint
```dart
// Automatically constructed as:
static String get proofOfDeliveryUrl => '$baseUrl/delivery-api.php?action=proof_of_delivery';
```

## Database Schema

Photos are stored locally in SQLite:

```sql
CREATE TABLE IF NOT EXISTS proof_of_delivery (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  delivery_boy_id INTEGER NOT NULL,
  photo_path TEXT NOT NULL,
  timestamp TEXT,
  latitude REAL,
  longitude REAL,
  upload_status TEXT DEFAULT 'pending',
  error_message TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

Sync checks for: `WHERE upload_status IN ('pending', 'failed')`

## Error Handling

### Network Errors
```dart
catch (DioException e) {
  updateProofStatus(proof.id!, 'failed', e.message);
  // Automatically retried when app resumes
}
```

### Directory Errors
```dart
catch (IOException e) {
  updateProofStatus(proof.id!, 'failed', 'File write failed');
  // Photo still stored in database for retry
}
```

### Server Errors (4xx, 5xx)
```dart
// Captured by HTTP response status check
if (response.statusCode != 200) {
  updateProofStatus(proof.id!, 'failed', 'Server error: ${response.statusCode}');
  // Retried automatically
}
```

## Troubleshooting

### Photos Not Syncing Automatically
**Check:**
1. Is server URL correct in `server_config.dart`?
2. Is backend endpoint deployed? (See BACKEND_SETUP_GUIDE.md)
3. Check logs: `flutter logs | grep "Syncing"`

### Photos Showing "Offline" Forever
**Solution:**
1. Verify internet connection: `adb shell ping 8.8.8.8`
2. Check server reachability: Visit URL in browser
3. Manually trigger retry: Press "Retry" button
4. Check upload permissions on server

### Crash on App Resume
**Fix:**
1. Ensure `WidgetsBindingObserver` is properly implemented
2. Check for null exceptions: `serverEndpoint` validation
3. Test with `try-catch` wrapping sync calls

## Files Modified

| File | Changes |
|------|---------|
| `lib/main.dart` | Added lifecycle observer for auto-sync |
| `lib/screens/order_details/view/proof_of_delivery_screen.dart` | Added retry dialog |
| `lib/config/server_config.dart` | Centralized URL configuration |
| `lib/services/proof_of_delivery_offline_service.dart` | (No changes needed) |

## Performance Notes

- SQLite queries are fast (< 100ms)
- Sync runs on UI thread but non-blocking
- Photos uploaded sequentially to avoid overwhelming server
- Progress logged but doesn't impact performance
- Database initialized on first access

## Next Steps

1. ✅ **Update server URL** in `server_config.dart`
2. ✅ **Deploy backend files** to server (see BACKEND_SETUP_GUIDE.md)
3. ✅ **Rebuild APK**: `flutter build apk --debug --no-tree-shake-icons`
4. ✅ **Test offline scenario**: Turn off WiFi and capture proof
5. ✅ **Verify auto-sync**: Turn on WiFi and reopen app

## API Integration

The system calls your backend endpoint:
```
POST /delivery-api.php?action=proof_of_delivery
Content-Type: multipart/form-data

Fields:
- order_id: int
- photo: file
- timestamp: string (ISO 8601)
- latitude: float
- longitude: float
- delivery_boy_id: int
```

Expected Response:
```json
{
  "success": true,
  "message": "Proof uploaded successfully",
  "proof_id": 12345
}
```

## Summary

The enhanced offline sync system ensures that:
- ✅ Photos never get lost due to network issues
- ✅ Automatic retry when connectivity returns
- ✅ Manual retry option available immediately
- ✅ Clear user feedback on upload status
- ✅ Comprehensive debug logging
- ✅ No data loss between app sessions

**Result**: Users can confidently deliver orders knowing their proofs are safely stored and will sync automatically.
