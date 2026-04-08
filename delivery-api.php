<?php
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json; charset=UTF-8');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit;
}

// Ensure error logging is enabled
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/delivery_api_error.log');

// Setup logging
$logFile = __DIR__ . '/delivery_api.log';
$VERSION = "1.0.4";
file_put_contents($logFile, "=================================================\n", FILE_APPEND);
file_put_contents($logFile, date('Y-m-d H:i:s') . " - NEW REQUEST\n", FILE_APPEND);
file_put_contents($logFile, "Method: " . $_SERVER['REQUEST_METHOD'] . "\n", FILE_APPEND);

// DB Configuration
$envFile = __DIR__ . '/../.env';
$dbHost = '127.0.0.1';
$dbName = 'u100875372_ecom';
$dbUser = 'u100875372_ecom';
$dbPass = 'Ecom@2@25@';

if (file_exists($envFile)) {
    $env = parse_ini_file($envFile);
    $dbHost = $env['DB_HOST'] ?? $dbHost;
    $dbName = $env['DB_DATABASE'] ?? $dbName;
    $dbUser = $env['DB_USERNAME'] ?? $dbUser;
    $dbPass = $env['DB_PASSWORD'] ?? $dbPass;
}

try {
    $pdo = new PDO("mysql:host=$dbHost;dbname=$dbName;charset=utf8", $dbUser, $dbPass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    
    // 🟢 SYNC SCHEMA: Auto-add fcm_token columns if missing
    try {
        $tables = ['orders', 'customers'];
        foreach ($tables as $table) {
            $hasCol = $pdo->query("SHOW COLUMNS FROM $table LIKE 'fcm_token'")->fetch();
            if (!$hasCol) {
                $pdo->exec("ALTER TABLE $table ADD COLUMN fcm_token VARCHAR(255) NULL");
            }
        }
    } catch (Exception $e) { /* ignore */ }
} catch (PDOException $e) {
    file_put_contents($logFile, "DB Connection failed: " . $e->getMessage() . "\n", FILE_APPEND);
    echo json_encode(["success" => false, "message" => "Database connection failed"]); exit;
}

// 🟢 HELPER: Centralized FCM Function
function send_fcm_notification($fcmToken, $title, $body, $payload_data = []) {
    $logPath = __DIR__ . '/fcm_debug.log';
    file_put_contents($logPath, date('Y-m-d H:i:s') . " - Entering send_fcm_notification for token: " . substr($fcmToken, 0, 10) . "...\n", FILE_APPEND);
    $keyFilePath = __DIR__ . '/firebase-credentials.json';
    
    if (!file_exists($keyFilePath)) {
        file_put_contents($logPath, date('Y-m-d H:i:s') . " - ERROR: Credentials missing\n", FILE_APPEND);
        return false;
    }

    try {
        $credentials = json_decode(file_get_contents($keyFilePath), true);
        $privateKey = $credentials['private_key'];
        $clientEmail = $credentials['client_email'];
        $projectId = $credentials['project_id'];

        $header = json_encode(['alg' => 'RS256', 'typ' => 'JWT']);
        $now = time();
        $claim = json_encode([
            'iss' => $clientEmail,
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => 'https://oauth2.googleapis.com/token',
            'exp' => $now + 3600,
            'iat' => $now
        ]);

        $base64UrlHeader = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
        $base64UrlClaim = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($claim));
        $signatureInput = $base64UrlHeader . '.' . $base64UrlClaim;
        openssl_sign($signatureInput, $signature, $privateKey, 'sha256WithRSAEncryption');
        $base64UrlSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));
        $jwt = $signatureInput . '.' . $base64UrlSignature;

        $ch = curl_init('https://oauth2.googleapis.com/token');
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $jwt
        ]));
        $tokenResponse = curl_exec($ch);
        $accessToken = json_decode($tokenResponse, true)['access_token'];

        if (!$accessToken) {
             file_put_contents($logPath, date('Y-m-d H:i:s') . " - ERROR: Auth failed: $tokenResponse\n", FILE_APPEND);
             return false;
        }

        $message = [
            'message' => [
                'token' => $fcmToken,
                'notification' => [
                    'title' => $title,
                    'body' => $body
                ],
                'data' => $payload_data,
                'android' => [
                    'priority' => 'high',
                    'notification' => [
                        'channel_id' => 'high_importance_channel',
                        'click_action' => 'FLUTTER_NOTIFICATION_CLICK'
                    ]
                ]
            ]
        ];

        $ch = curl_init("https://fcm.googleapis.com/v1/projects/$projectId/messages:send");
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: Bearer ' . $accessToken,
            'Content-Type: application/json'
        ]);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($message));
        $result = curl_exec($ch);
        file_put_contents($logPath, date('Y-m-d H:i:s') . " - Result: $result - Token: " . substr($fcmToken, 0, 10) . "...\n", FILE_APPEND);
        return true;
    } catch (Exception $e) {
        file_put_contents($logPath, date('Y-m-d H:i:s') . " - Exception: " . $e->getMessage() . "\n", FILE_APPEND);
        return false;
    }
}

// Get Request Data
$rawData = file_get_contents('php://input');
file_put_contents($logFile, "Raw Input: " . $rawData . "\n", FILE_APPEND);

$data = json_decode($rawData, true);
$action = $_GET['action'] ?? $data['action'] ?? $_REQUEST['action'] ?? '';
$response = ["success" => false, "message" => "Invalid Action"];

try {
    // 1. DELIVERY BOY LOGIN (Support Email or Phone)
    if ($action == 'login') {
        $username = $data['email'] ?? $data['phone'] ?? $_REQUEST['email'] ?? $_REQUEST['phone'] ?? '';
        $password = $data['password'] ?? $_REQUEST['password'] ?? '';

        if (!$username || !$password) {
            echo json_encode(["success" => false, "message" => "Email/Phone and password are required"]); exit;
        }
        
        // Search by email or phone
        $sql = "SELECT id, name, email, phone, is_active FROM delivery_boys WHERE (email = ? OR phone = ?) AND password = ? LIMIT 1";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([$username, $username, $password]);
        $user = $stmt->fetch();

        if ($user) {
            if ($user['is_active'] != 1) {
                $response = ["success" => false, "message" => "Account is deactivated."];
            } else {
                $token = bin2hex(random_bytes(16));
                $fcm_token = $data['fcm_token'] ?? $_REQUEST['fcm_token'] ?? '';
                
                $updateSql = "UPDATE delivery_boys SET token = ?" . (!empty($fcm_token) ? ", fcm_token = ?" : "") . " WHERE id = ?";
                $updateParams = !empty($fcm_token) ? [$token, $fcm_token, $user['id']] : [$token, $user['id']];
                $pdo->prepare($updateSql)->execute($updateParams);

                $response = [
                    "success" => true, 
                    "message" => "Login successful",
                    "data" => [
                        "id" => $user['id'],
                        "name" => $user['name'],
                        "email" => $user['email'],
                        "phone" => $user['phone'],
                        "token" => $token
                    ]
                ];
            }
        } else {
            $response = ["success" => false, "message" => "Invalid credentials"];
        }
    }

    // 1b. DELIVERY BOY SIGNUP
    elseif ($action == 'register') {
        $name = $data['name'] ?? $_REQUEST['name'] ?? '';
        $email = $data['email'] ?? $_REQUEST['email'] ?? '';
        $phone = $data['phone'] ?? $_REQUEST['phone'] ?? '';
        $password = $data['password'] ?? $_REQUEST['password'] ?? '';
        $fcm_token = $data['fcm_token'] ?? $_REQUEST['fcm_token'] ?? '';

        if (!$name || !$phone || !$password) {
            echo json_encode(["success" => false, "message" => "Name, Phone and password are required"]); exit;
        }

        // Check if email or phone already exists
        $stmt = $pdo->prepare("SELECT id FROM delivery_boys WHERE email = ? OR phone = ? LIMIT 1");
        $stmt->execute([$email, $phone]);
        if ($stmt->fetch()) {
            echo json_encode(["success" => false, "message" => "Email or Phone already registered"]); exit;
        }

        $token = bin2hex(random_bytes(16));
        $sql = "INSERT INTO delivery_boys (name, email, phone, password, token, fcm_token, is_active) VALUES (?, ?, ?, ?, ?, ?, 1)";
        $stmt = $pdo->prepare($sql);
        
        if ($stmt->execute([$name, $email, $phone, $password, $token, $fcm_token])) {
            $userId = $pdo->lastInsertId();
            $response = [
                "success" => true,
                "message" => "Registration successful",
                "data" => [
                    "id" => $userId,
                    "name" => $name,
                    "email" => $email,
                    "phone" => $phone,
                    "token" => $token
                ]
            ];
        } else {
            $response = ["success" => false, "message" => "Registration failed"];
        }
    }

    // 2. GET DASHBOARD / ORDERS
    elseif ($action == 'get_orders') {
        $token = $_SERVER['HTTP_AUTHORIZATION'] ?? $data['token'] ?? $_REQUEST['token'] ?? '';
        $token = str_replace('Bearer ', '', $token);

        $stmt = $pdo->prepare("SELECT id FROM delivery_boys WHERE token = ? LIMIT 1");
        $stmt->execute([$token]);
        $deliveryBoy = $stmt->fetch();

        if (!$deliveryBoy) {
             echo json_encode(["success" => false, "message" => "Unauthorized. Invalid Token."]); exit;
        }

        $deliveryBoyId = $deliveryBoy['id'];

        $sql = "
            SELECT 
                o.id, 
                o.increment_id, 
                o.status, 
                o.grand_total as total,
                o.created_at,
                CONCAT(COALESCE(o.customer_first_name, ''), ' ', COALESCE(o.customer_last_name, '')) as customer_name,
                (SELECT phone FROM order_addresses WHERE order_id = o.id AND address_type LIKE '%shipping%' LIMIT 1) as customer_phone,
                (SELECT CONCAT(address1, ', ', city, ', ', state, ' ', postcode) FROM order_addresses WHERE order_id = o.id AND address_type LIKE '%shipping%' LIMIT 1) as customer_address,
                (SELECT GROUP_CONCAT(name SEPARATOR ', ') FROM order_items WHERE order_id = o.id) as items
            FROM orders o
            JOIN order_deliveries od ON o.id = od.order_id
            WHERE od.delivery_boy_id = ?
            ORDER BY o.id DESC
        ";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([$deliveryBoyId]);
        $orders = $stmt->fetchAll();

        $active_orders = [];
        $completed_orders = [];

        foreach ($orders as $o) {
            $formatted = [
                "id" => $o['id'],
                "order_number" => '#' . ($o['increment_id'] ?: $o['id']),
                "status" => ucfirst($o['status']),
                "total" => "₹" . number_format($o['total'] ?? 0, 2),
                "date" => date('d M Y, h:i A', strtotime($o['created_at'])),
                "customer_name" => $o['customer_name'] ?: 'Guest',
                "customer_phone" => $o['customer_phone'] ?: 'N/A',
                "customer_address" => $o['customer_address'] ?: 'Address not found',
                "items" => $o['items'] ?? 'Unknown Items'
            ];

            if (in_array($o['status'], ['completed', 'delivered', 'canceled', 'closed'])) {
                $completed_orders[] = $formatted;
            } else {
                $active_orders[] = $formatted;
            }
        }

        $response = [
            "success" => true,
            "data" => ["active" => $active_orders, "history" => $completed_orders]
        ];
    }

    // 3. GET AVAILABLE ORDERS (Unassigned)
    elseif ($action == 'get_available_orders') {
        $sql = "
            SELECT 
                o.id, 
                o.increment_id, 
                o.status, 
                o.grand_total as total,
                o.created_at,
                CONCAT(COALESCE(o.customer_first_name, ''), ' ', COALESCE(o.customer_last_name, '')) as customer_name,
                (SELECT CONCAT(address1, ', ', city, ', ', state, ' ', postcode) FROM order_addresses WHERE order_id = o.id AND address_type LIKE '%shipping%' LIMIT 1) as customer_address,
                (SELECT GROUP_CONCAT(name SEPARATOR ', ') FROM order_items WHERE order_id = o.id) as items
            FROM orders o
            LEFT JOIN order_deliveries od ON o.id = od.order_id
            WHERE od.id IS NULL 
            AND o.status IN ('pending', 'processing', 'ready_for_pickup', 'packed')
            ORDER BY o.id DESC
        ";
        $stmt = $pdo->prepare($sql);
        $stmt->execute();
        $orders = $stmt->fetchAll();

        $available_orders = [];
        foreach ($orders as $o) {
            $available_orders[] = [
                "id" => $o['id'],
                "order_number" => '#' . ($o['increment_id'] ?: $o['id']),
                "status" => ucfirst($o['status']),
                "total" => "₹" . number_format($o['total'] ?? 0, 2),
                "date" => date('d M Y, h:i A', strtotime($o['created_at'])),
                "customer_name" => $o['customer_name'] ?: 'Guest',
                "customer_address" => $o['customer_address'] ?: 'Address not found',
                "items" => $o['items'] ?? 'Unknown Items'
            ];
        }

        $response = [
            "success" => true,
            "data" => $available_orders
        ];
    }

    // 4. ACCEPT ORDER
    elseif ($action == 'accept_order') {
        $token = $_SERVER['HTTP_AUTHORIZATION'] ?? $data['token'] ?? $_REQUEST['token'] ?? '';
        $token = str_replace('Bearer ', '', $token);
        $orderId = $data['order_id'] ?? $_REQUEST['order_id'] ?? '';

        if (!$orderId) {
             echo json_encode(["success" => false, "message" => "order_id is required"]); exit;
        }

        $stmt = $pdo->prepare("SELECT id FROM delivery_boys WHERE token = ? LIMIT 1");
        $stmt->execute([$token]);
        $deliveryBoy = $stmt->fetch();

        if (!$deliveryBoy) {
             echo json_encode(["success" => false, "message" => "Unauthorized. Invalid Token."]); exit;
        }

        $deliveryBoyId = $deliveryBoy['id'];

        // Check if order is already assigned
        $stmt = $pdo->prepare("SELECT id FROM order_deliveries WHERE order_id = ?");
        $stmt->execute([$orderId]);
        if ($stmt->fetch()) {
            echo json_encode(["success" => false, "message" => "Order already assigned to someone else"]); exit;
        }

        // Assign order
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare("INSERT INTO order_deliveries (order_id, delivery_boy_id, status) VALUES (?, ?, 'assigned')");
            $stmt->execute([$orderId, $deliveryBoyId]);
            
            // Update order status to processing
            $pdo->prepare("UPDATE orders SET status = 'processing' WHERE id = ?")->execute([$orderId]);
            
            $pdo->commit();
            $response = ["success" => true, "message" => "Order accepted successfully"];
        } catch (Exception $e) {
            $pdo->rollBack();
            $response = ["success" => false, "message" => "Failed to accept order: " . $e->getMessage()];
        }
    }

    // 5. UPDATE ORDER STATUS (Renumbered)
    elseif ($action == 'update_status') {
         $orderId = $data['order_id'] ?? $_REQUEST['order_id'] ?? '';
         $newStatus = $data['status'] ?? $_REQUEST['status'] ?? ''; 

         if (!$orderId || !$newStatus) {
              echo json_encode(["success" => false, "message" => "Missing order_id or status"]); exit;
         }

         $stmt = $pdo->prepare("UPDATE orders SET status = ? WHERE id = ?");
         if ($stmt->execute([$newStatus, $orderId])) {
              // 🔴 Notification Logic
              $statusClean = strtolower(str_replace([' ', '_'], '', $newStatus));
              
              if (in_array($statusClean, ['pickedup', 'delivered', 'completed'])) {
                   // Update order_deliveries for tracking consistency
                   if ($statusClean == 'delivered' || $statusClean == 'completed') {
                       try {
                           $stmt2 = $pdo->prepare("UPDATE order_deliveries SET status = ?, delivered_at = NOW() WHERE order_id = ?");
                           $stmt2->execute(['delivered', $orderId]);
                       } catch (Exception $e) { /* silent fail */ }
                   }

                   $fcmToken = null;
                   $incrementId = $orderId;
                   $logPath = __DIR__ . '/fcm_debug.log';
                   
                   try {
                       // 1. Fetch info and Token linked to ORDER
                       $q = $pdo->prepare("SELECT fcm_token, customer_email, customer_id, increment_id FROM orders WHERE id = ?");
                       $q->execute([$orderId]);
                       $res = $q->fetch();
                       
                       if ($res) {
                           $incrementId = !empty($res['increment_id']) ? $res['increment_id'] : $orderId;
                           if (!empty($res['fcm_token'])) {
                               $fcmToken = $res['fcm_token'];
                               file_put_contents($logPath, date('Y-m-d H:i:s') . " - Token found in orders table for ID $orderId\n", FILE_APPEND);
                           } else {
                               // 2. Fallback: Token linked to CUSTOMER ID
                               if (!empty($res['customer_id'])) {
                                   $q2 = $pdo->prepare("SELECT fcm_token FROM customers WHERE id = ? AND fcm_token IS NOT NULL");
                                   $q2->execute([$res['customer_id']]);
                                   $res2 = $q2->fetch();
                                   if ($res2) {
                                       $fcmToken = $res2['fcm_token'];
                                       file_put_contents($logPath, date('Y-m-d H:i:s') . " - Token found in customers table for CustID " . $res['customer_id'] . "\n", FILE_APPEND);
                                   }
                               }
                               // 3. Fallback: Token matched by EMAIL
                               if (!$fcmToken && !empty($res['customer_email'])) {
                                   $q3 = $pdo->prepare("SELECT fcm_token FROM customers WHERE email = ? AND fcm_token IS NOT NULL LIMIT 1");
                                   $q3->execute([$res['customer_email']]);
                                   $res3 = $q3->fetch();
                                   if ($res3) { $fcmToken = $res3['fcm_token']; }
                               }
                           }
                       }
                   } catch (Exception $e) { /* Log error */ }

                   if ($fcmToken) {
                        $title = ($statusClean == 'pickedup') ? "Order Picked Up! 🛵" : "Order Delivered! 🎉";
                        $body = ($statusClean == 'pickedup') 
                                ? "Your delivery partner picked up your order #$incrementId." 
                                : "Your order #$incrementId has been successfully delivered. Thank you for shopping with us!";
                        $action_payload = ($statusClean == 'pickedup') ? "track_order" : "order_details";

                        send_fcm_notification(
                            $fcmToken, 
                            $title, 
                            $body,
                            ["action" => $action_payload, "order_id" => (string)$orderId]
                        );
                   } else {
                       file_put_contents($logPath, date('Y-m-d H:i:s') . " - NO TOKEN FOUND FOR ORDER $orderId\n", FILE_APPEND);
                   }
              }
              $response = ["success" => true, "message" => "Order updated to $newStatus"];
         }
    }

    // 4. SYNC FCM TOKEN (Called by App)
    elseif ($action == 'update_customer_fcm') {
        $customerId = $data['customer_id'] ?? $_REQUEST['customer_id'] ?? '';
        $email = $data['email'] ?? $_REQUEST['email'] ?? '';
        $fcmToken = $data['fcm_token'] ?? $_REQUEST['fcm_token'] ?? '';
        $orderId = $data['order_id'] ?? $_REQUEST['order_id'] ?? '';
        
        if ((!$customerId && !$email) || !$fcmToken) {
            echo json_encode(["success" => false, "message" => "Missing customer_id/email or fcm_token"]);
            exit;
        }

        try {
            // 1. Update Customers table always
            if (!empty($customerId)) {
                $stmt = $pdo->prepare("UPDATE customers SET fcm_token = ? WHERE id = ?");
                $stmt->execute([$fcmToken, $customerId]);
            } elseif (!empty($email)) {
                $stmt = $pdo->prepare("UPDATE customers SET fcm_token = ? WHERE email = ?");
                $stmt->execute([$fcmToken, $email]);
            }
            
            // 2. Update specific order if provided
            if (!empty($orderId)) {
                $stmt = $pdo->prepare("UPDATE orders SET fcm_token = ? WHERE id = ?");
                $stmt->execute([$fcmToken, $orderId]);
            }
            
            // 3. ALWAYS update ALL active orders for this customer (fallback + proactive)
            $where = []; $params = [$fcmToken];
            if (!empty($customerId)) { $where[] = "customer_id = ?"; $params[] = $customerId; }
            if (!empty($email)) { $where[] = "customer_email = ?"; $params[] = $email; }
            
            if (!empty($where)) {
                $cond = "(" . implode(" OR ", $where) . ") AND status NOT IN ('completed', 'delivered', 'canceled', 'closed')";
                $sql = "UPDATE orders SET fcm_token = ? WHERE $cond";
                $stmt = $pdo->prepare($sql);
                $stmt->execute($params);
            }

            echo json_encode(["success" => true, "message" => "FCM Token synced to Customer and All Active Orders"]);
        } catch (Exception $e) {
            echo json_encode(["success" => false, "message" => "DB Error: " . $e->getMessage()]);
        }
    }

    // 6. GET DELIVERY BOY PROFILE STATS (Deliveries, Ratings, Earnings)
    elseif ($action == 'get_profile') {
        $token = $_SERVER['HTTP_AUTHORIZATION'] ?? $data['token'] ?? $_REQUEST['token'] ?? '';
        $token = str_replace('Bearer ', '', $token);

        $stmt = $pdo->prepare("SELECT id, name, email, phone FROM delivery_boys WHERE token = ? LIMIT 1");
        $stmt->execute([$token]);
        $deliveryBoy = $stmt->fetch();

        if (!$deliveryBoy) {
             echo json_encode(["success" => false, "message" => "Unauthorized. Invalid Token."]); exit;
        }

        $deliveryBoyId = $deliveryBoy['id'];

        // Calculate Stats
        $statsSql = "
            SELECT 
                COUNT(*) as total_deliveries,
                COALESCE(AVG(rating), 0) as avg_rating,
                SUM(CASE WHEN status = 'delivered' THEN delivery_fee ELSE 0 END) as total_earnings
            FROM order_deliveries 
            WHERE delivery_boy_id = ?
        ";
        $stmt = $pdo->prepare($statsSql);
        $stmt->execute([$deliveryBoyId]);
        $stats = $stmt->fetch();

        $response = [
            "success" => true,
            "data" => [
                "id" => $deliveryBoy['id'],
                "name" => $deliveryBoy['name'],
                "email" => $deliveryBoy['email'],
                "phone" => $deliveryBoy['phone'],
                "total_deliveries" => (int)$stats['total_deliveries'],
                "avg_rating" => round((float)$stats['avg_rating'], 1),
                "total_earnings" => (float)($stats['total_earnings'] ?? 0)
            ]
        ];
    }

    // 7. SUBMIT DELIVERY RATING (Called by Customer)
    elseif ($action == 'rate_delivery') {
        $orderId = $data['order_id'] ?? $_REQUEST['order_id'] ?? '';
        $rating = $data['rating'] ?? $_REQUEST['rating'] ?? '';
        $comment = $data['comment'] ?? $_REQUEST['comment'] ?? '';

        if (!$orderId || !$rating) {
            echo json_encode(["success" => false, "message" => "order_id and rating (1-5) are required"]); exit;
        }

        $stmt = $pdo->prepare("UPDATE order_deliveries SET rating = ?, rating_comment = ? WHERE order_id = ?");
        if ($stmt->execute([$rating, $comment, $orderId])) {
            $response = ["success" => true, "message" => "Thank you for your feedback!"];
        } else {
            $response = ["success" => false, "message" => "Failed to submit rating."];
        }
    }

    // 8. DEBUG TOOLS
    elseif ($action == 'get_fcm_logs') {
        echo file_get_contents(__DIR__ . '/fcm_debug.log'); exit;
    }
    elseif ($action == 'get_info') {
        echo json_encode(["success" => true, "version" => $VERSION, "time" => date('Y-m-d H:i:s')]); exit;
    }
    elseif ($action == 'debug_token') {
        $cid = $_GET['customer_id'] ?? ''; $oid = $_GET['order_id'] ?? '';
        $res = [];
        if($cid) $res['customer'] = $pdo->query("SELECT id, email, fcm_token FROM customers WHERE id = '$cid'")->fetch();
        if($oid) $res['order'] = $pdo->query("SELECT id, customer_id, fcm_token FROM orders WHERE id = '$oid'")->fetch();
        echo json_encode(["success" => true, "data" => $res]); exit;
    }
    elseif ($action == 'get_error_logs') {
        echo file_exists(__DIR__ . '/delivery_api.log') ? file_get_contents(__DIR__ . '/delivery_api.log') : "No logs."; exit;
    }
    elseif ($action == 'send_self_test_notification') {
        $token = $_GET['fcm_token'] ?? $data['fcm_token'] ?? '';
        $success = send_fcm_notification($token, "Test Successful! 🎉", "Notification system is online.", ["action" => "test_click"]);
        echo json_encode(["success" => $success]); exit;
    }

    // 10. PROOF OF DELIVERY UPLOAD
    elseif ($action == 'proof_of_delivery') {
        $orderId = $_POST['order_id'] ?? $_GET['order_id'] ?? '';
        $latitude = $_POST['latitude'] ?? $_GET['latitude'] ?? 0;
        $longitude = $_POST['longitude'] ?? $_GET['longitude'] ?? 0;
        $timestamp = $_POST['timestamp'] ?? $_GET['timestamp'] ?? date('Y-m-d H:i:s');
        $token = $_POST['token'] ?? $_GET['token'] ?? '';

        if (!$orderId || !$token) {
            echo json_encode(["success" => false, "message" => "order_id and token are required"]);
            exit;
        }

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

            // Create uploads directory if not exists
            $uploadDir = __DIR__ . '/uploads/proof_of_delivery/';
            if (!is_dir($uploadDir)) {
                mkdir($uploadDir, 0755, true);
            }

            $photoPath = null;
            $photoData = null;

            // Handle file upload
            if (isset($_FILES['photo'])) {
                $file = $_FILES['photo'];
                if ($file['error'] === UPLOAD_ERR_OK) {
                    $fileName = time() . '_' . uniqid() . '.jpg';
                    $fullPath = $uploadDir . $fileName;

                    if (move_uploaded_file($file['tmp_name'], $fullPath)) {
                        $photoPath = 'uploads/proof_of_delivery/' . $fileName;
                        $photoData = file_get_contents($fullPath);
                        file_put_contents($logFile, "Photo uploaded: $photoPath\n", FILE_APPEND);
                    } else {
                        throw new Exception("Failed to move uploaded file");
                    }
                } else {
                    throw new Exception("File upload error: " . $file['error']);
                }
            }

            // Check if proof already exists
            $checkStmt = $pdo->prepare("SELECT id FROM proof_of_deliveries WHERE order_id = ? AND delivery_boy_id = ?");
            $checkStmt->execute([$orderId, $deliveryBoyId]);
            $existing = $checkStmt->fetch();

            if ($existing) {
                // Update existing proof
                $updateStmt = $pdo->prepare("UPDATE proof_of_deliveries 
                    SET photo_path = COALESCE(?, photo_path), 
                        photo_data = COALESCE(?, photo_data), 
                        latitude = ?, 
                        longitude = ?, 
                        timestamp = ?, 
                        upload_status = 'uploaded'
                    WHERE order_id = ? AND delivery_boy_id = ?");
                $updateStmt->execute([$photoPath, $photoData, $latitude, $longitude, $timestamp, $orderId, $deliveryBoyId]);
                file_put_contents($logFile, "Proof updated for order $orderId\n", FILE_APPEND);
            } else {
                // Insert new proof
                $insertStmt = $pdo->prepare("INSERT INTO proof_of_deliveries 
                    (order_id, delivery_boy_id, photo_path, photo_data, latitude, longitude, timestamp, upload_status)
                    VALUES (?, ?, ?, ?, ?, ?, ?, 'uploaded')");
                $insertStmt->execute([$orderId, $deliveryBoyId, $photoPath, $photoData, $latitude, $longitude, $timestamp]);
                file_put_contents($logFile, "Proof inserted for order $orderId\n", FILE_APPEND);
            }

            // Update order status to delivered
            $orderStmt = $pdo->prepare("UPDATE orders SET order_status = 'delivered' WHERE id = ?");
            $orderStmt->execute([$orderId]);

            // Update order_deliveries status to delivered
            $deliveryStmt = $pdo->prepare("UPDATE order_deliveries SET status = 'delivered', delivered_at = NOW() WHERE order_id = ? AND delivery_boy_id = ?");
            $deliveryStmt->execute([$orderId, $deliveryBoyId]);

            $response = [
                "success" => true,
                "message" => "Proof of delivery uploaded successfully",
                "proof_id" => $pdo->lastInsertId()
            ];

        } catch (Exception $e) {
            file_put_contents($logFile, "Proof upload error: " . $e->getMessage() . "\n", FILE_APPEND);
            $response = ["success" => false, "message" => "Error: " . $e->getMessage()];
        }
        exit;
    }

    // 9. CHECK IF ORDER IS ALREADY RATED
    elseif ($action == 'check_rating') {
        $orderId = $data['order_id'] ?? $_REQUEST['order_id'] ?? '';
        if (!$orderId) {
            echo json_encode(["success" => false, "message" => "order_id is required"]); exit;
        }

        $stmt = $pdo->prepare("SELECT rating FROM order_deliveries WHERE order_id = ? AND rating IS NOT NULL LIMIT 1");
        $stmt->execute([$orderId]);
        $result = $stmt->fetch();

        echo json_encode([
            "success" => true,
            "is_rated" => (bool)$result
        ]);
        exit;
    }

    // 🟠 AUTO-MIGRATE: Run this via URL to fix missing columns if Profile screen errors
    elseif ($action == 'migrate') {
        try {
            $pdo->exec("ALTER TABLE order_deliveries ADD COLUMN rating TINYINT NULL DEFAULT NULL");
            $pdo->exec("ALTER TABLE order_deliveries ADD COLUMN rating_comment TEXT NULL DEFAULT NULL");
            $pdo->exec("ALTER TABLE order_deliveries ADD COLUMN delivery_fee DECIMAL(10, 2) NOT NULL DEFAULT 20.00");
            echo "Success: Database updated successfully! You can now use the Profile screen.";
        } catch (Exception $e) {
            echo "Notice: Column may already exist or error: " . $e->getMessage();
        }
        exit;
    }

} catch (Throwable $e) {
    file_put_contents($logFile, "FATAL: " . $e->getMessage() . "\n", FILE_APPEND);
    $response = ["success" => false, "message" => "API Error: " . $e->getMessage()];
}

$response['version'] = $VERSION;
echo json_encode($response);
?>
