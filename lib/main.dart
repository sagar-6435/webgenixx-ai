import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'utils/theme.dart';

void main() async {
  // Ensure Flutter engine bindings are completely ready
  WidgetsFlutterBinding.ensureInitialized();

  // Boot Local Hive Database Cache
  await StorageService.init();

  // Boot SharedPreferences & Network Client
  await ApiService.init();

  // Fire up the Flutter engine
  runApp(
    const ProviderScope(
      child: WebgenixxCallerApp(),
    ),
  );
}

class WebgenixxCallerApp extends StatelessWidget {
  const WebgenixxCallerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Webgenixx AI Caller Agent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
