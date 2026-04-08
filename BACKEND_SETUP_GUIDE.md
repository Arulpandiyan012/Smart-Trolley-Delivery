# Backend Setup Guide - Proof of Delivery Integration

## Backend Files Found
You have PHP backend files in your Downloads folder:
- `delivery-api.php` - Main delivery API (v1.0.4)
- `setup_delivery_db.php` - Database initialization
- `tracking-api.php` - Tracking API
- Other mobile APIs

## Issue Found
Your backend **does NOT have** a proof of delivery endpoint yet. This is why the app falls back to offline mode.

## Solution

### Step 1: Add Proof of Delivery Table
Run this SQL to create the proof of delivery table:

```sql
CREATE TABLE IF NOT EXISTS proof_of_deliveries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT UNSIGNED NOT NULL,
    delivery_boy_id INT NOT NULL,
    photo_path VARCHAR(500),
    photo_data LONGBLOB,
    timestamp VARCHAR(255),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    upload_status VARCHAR(50) DEFAULT 'uploaded',
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (delivery_boy_id) REFERENCES delivery_boys(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);
```

### Step 2: Add API Endpoint to delivery-api.php
Add this code to your `delivery-api.php` file (after line 500, before the final else):

```php
// PROOF OF DELIVERY UPLOAD
elseif ($action == 'proof_of_delivery') {
    $token = $_GET['token'] ?? $_POST['token'] ?? '';
    $orderId = $_GET['order_id'] ?? $_POST['order_id'] ?? '';
    $latitude = $_GET['latitude'] ?? $_POST['latitude'] ?? 0;
    $longitude = $_GET['longitude'] ?? $_POST['longitude'] ?? 0;
    $timestamp = $_GET['timestamp'] ?? $_POST['timestamp'] ?? date('Y-m-d H:i:s');

    try {
        // Verify delivery boy
        $stmt = $pdo->prepare("SELECT id FROM delivery_boys WHERE token = ? LIMIT 1");
        $stmt->execute([$token]);
        $deliveryBoy = $stmt->fetch();

        if (!$deliveryBoy) {
            echo json_encode(["success" => false, "message" => "Invalid token"]);
            exit;
        }

        $deliveryBoyId = $deliveryBoy['id'];

        // Check if proof already exists
        $checkStmt = $pdo->prepare("SELECT id FROM proof_of_deliveries WHERE order_id = ? AND delivery_boy_id = ?");
        $checkStmt->execute([$orderId, $deliveryBoyId]);
        $existing = $checkStmt->fetch();

        // Handle file upload
        if (isset($_FILES['photo'])) {
            $file = $_FILES['photo'];
            $fileName = time() . '_' . md5_file($file['tmp_name']) . '.jpg';
            $uploadDir = __DIR__ . '/uploads/proof_of_delivery/';
            
            if (!is_dir($uploadDir)) {
                mkdir($uploadDir, 0755, true);
            }

            if (move_uploaded_file($file['tmp_name'], $uploadDir . $fileName)) {
                $photoPath = 'uploads/proof_of_delivery/' . $fileName;
                $photoData = file_get_contents($uploadDir . $fileName);

                if ($existing) {
                    // Update existing
                    $stmt = $pdo->prepare("UPDATE proof_of_deliveries 
                        SET photo_path = ?, photo_data = ?, latitude = ?, longitude = ?, timestamp = ?, upload_status = 'uploaded'
                        WHERE order_id = ? AND delivery_boy_id = ?");
                    $stmt->execute([$photoPath, $photoData, $latitude, $longitude, $timestamp, $orderId, $deliveryBoyId]);
                } else {
                    // Insert new
                    $stmt = $pdo->prepare("INSERT INTO proof_of_deliveries 
                        (order_id, delivery_boy_id, photo_path, photo_data, latitude, longitude, timestamp, upload_status)
                        VALUES (?, ?, ?, ?, ?, ?, ?, 'uploaded')");
                    $stmt->execute([$orderId, $deliveryBoyId, $photoPath, $photoData, $latitude, $longitude, $timestamp]);
                }

                // Update order status to delivered
                $orderStmt = $pdo->prepare("UPDATE orders SET order_status = 'delivered' WHERE id = ?");
                $orderStmt->execute([$orderId]);

                echo json_encode([
                    "success" => true,
                    "message" => "Proof of delivery uploaded successfully",
                    "proof_id" => $pdo->lastInsertId()
                ]);
            } else {
                echo json_encode(["success" => false, "message" => "File upload failed"]);
            }
        } else {
            echo json_encode(["success" => false, "message" => "No photo provided"]);
        }

    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Error: " . $e->getMessage()]);
    }
    exit;
}
```

### Step 3: Update Flutter App with Backend URL

In your app at [lib/screens/order_details/view/proof_of_delivery_screen.dart](lib/screens/order_details/view/proof_of_delivery_screen.dart#L220), replace:

```dart
serverEndpoint: 'http://your-server.com/api/proof-of-delivery',
```

With your actual backend URL:

```dart
serverEndpoint: 'https://yourdomain.com/delivery-api.php?action=proof_of_delivery',
```

## Database Credentials (from setup_delivery_db.php)
- **Host:** 127.0.0.1 (or your hosting domain)
- **Database:** u100875372_ecom
- **User:** u100875372_ecom
- **Password:** Ecom@2@25@

## Testing the Integration
1. Run the setup SQL to create the proof_of_deliveries table
2. Update delivery-api.php with the new endpoint
3. Update Flutter app with the correct backend URL
4. Rebuild APK: `flutter build apk --debug --no-tree-shake-icons`
5. Test proof of delivery workflow

## File Paths
- Backend files location: `C:\Users\kamar\Downloads\`
- Copy files to your server: `/public_html/` or `/www/`
- Create uploads folder: `/public_html/uploads/proof_of_delivery/`

