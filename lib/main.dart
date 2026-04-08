import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smart_trolley_delivery/services/fcm_service.dart';
import 'package:smart_trolley_delivery/services/proof_of_delivery_offline_service.dart';
import 'package:smart_trolley_delivery/routes/app_routes.dart';
import 'package:smart_trolley_delivery/utils/app_theme.dart';
import 'package:smart_trolley_delivery/config/server_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FCMService.initialize();
  
  // Initialize offline service at startup
  ProofOfDeliveryOfflineService();
  
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Trolley Delivery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
      navigatorObservers: [_AppLifecycleObserver()],
    );
  }
}

class _AppLifecycleObserver extends NavigatorObserver with WidgetsBindingObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // Sync pending proofs when app returns to foreground
      debugPrint('🔄 App resumed - syncing pending proofs...');
      try {
        await ProofOfDeliveryOfflineService().syncPendingProofs(
          serverEndpoint: ServerConfig.proofOfDeliveryUrl,
          onProgress: (current, total) {
            debugPrint('📤 Syncing proofs: $current/$total');
          },
        );
      } catch (e) {
        debugPrint('❌ Error syncing proofs: $e');
      }
    }
  }
}
