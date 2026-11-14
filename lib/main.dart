import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';

import 'firebase_app_check_options.dart';
import 'firebase_options.dart';
import 'screens/marketplace/marketplace_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(FirebaseAppCheckOptions.reCaptchaSiteKey),
      );
    } else {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttestWithDeviceCheckFallback,
      );
    }
    runApp(const ShopWaveApp());
  } catch (error) {
    // Fail closed: never fall back to local seed accounts or fake marketplace
    // records when the Firebase project is missing or misconfigured.
    runApp(FirebaseSetupRequiredApp(error: error));
  }
}

class FirebaseSetupRequiredApp extends StatelessWidget {
  const FirebaseSetupRequiredApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Shop Wave setup required',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 54),
                    const SizedBox(height: 18),
                    const Text(
                      'Firebase setup is required',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Shop Wave is configured to use Firebase for accounts and marketplace data. Configure the selected Firebase project with FlutterFire before running the production app. No local demo data is shown as a fallback.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Backwards-compatible app entry point for older widget tests.
class MyApp extends ShopWaveApp {
  const MyApp({super.key});
}
