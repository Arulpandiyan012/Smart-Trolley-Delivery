import 'package:flutter/material.dart';
import 'package:smart_trolley_delivery/screens/splash/splash_screen.dart';
import 'package:smart_trolley_delivery/screens/login/login_screen.dart';
import 'package:smart_trolley_delivery/screens/dashboard/view/dashboard_screen.dart';
import 'package:smart_trolley_delivery/screens/profile/view/profile_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String profile = '/profile';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
