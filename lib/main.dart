import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:veducation_app/providers/auth_provider.dart';
import 'package:veducation_app/providers/duel_provider.dart';
import 'package:veducation_app/providers/leaderboard_provider.dart';
import 'package:veducation_app/screens/splash_screen.dart';
import 'package:veducation_app/screens/admin/admin_login_screen.dart';
import 'package:veducation_app/utils/app_theme.dart';

void main() {
  runApp(const VEducationApp());
}

class VEducationApp extends StatelessWidget {
  const VEducationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DuelProvider()),
        ChangeNotifierProvider(create: (_) => LeaderboardProvider()),
      ],
      child: MaterialApp(
        title: 'V Education',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        routes: {
          '/admin/login': (context) => const AdminLoginScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle hash-based routing for web admin portal
          if (kIsWeb) {
            final uri = Uri.base;
            final hash = uri.fragment;
            if (hash == '/admin/login' || hash.startsWith('/admin/login')) {
              return MaterialPageRoute(
                builder: (_) => const AdminLoginScreen(),
                settings: const RouteSettings(name: '/admin/login'),
              );
            }
          }
          return null;
        },
      ),
    );
  }
}

