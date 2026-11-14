import 'package:flutter/material.dart';

import 'screens/marketplace/marketplace_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShopWaveApp());
}

/// Backwards-compatible app entry point for older widget tests.
class MyApp extends ShopWaveApp {
  const MyApp({super.key});
}
