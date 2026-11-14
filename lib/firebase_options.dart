import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase's client configuration is deliberately supplied by the project
/// owner at build time. No project ID or API key is guessed or embedded here.
/// Run `flutterfire configure` for the selected Firebase project, or provide
/// the values in firebase.config.json using --dart-define-from-file.
class DefaultFirebaseOptions {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static FirebaseOptions get currentPlatform {
    final appId = kIsWeb
        ? _webAppId
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => _androidAppId,
            TargetPlatform.iOS => _iosAppId,
            _ => '',
          };
    if (_apiKey.isEmpty ||
        _projectId.isEmpty ||
        _senderId.isEmpty ||
        _storageBucket.isEmpty ||
        appId.isEmpty ||
        (kIsWeb && _authDomain.isEmpty)) {
      throw StateError(
        'Firebase is not configured for this build. Configure the selected '
        'project with flutterfire configure or provide FIREBASE_* values.',
      );
    }
    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: _apiKey,
        appId: appId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        storageBucket: _storageBucket,
        authDomain: _authDomain.isEmpty ? null : _authDomain,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return FirebaseOptions(
        apiKey: _apiKey,
        appId: appId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        storageBucket: _storageBucket,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return FirebaseOptions(
        apiKey: _apiKey,
        appId: appId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        storageBucket: _storageBucket,
        iosBundleId: _iosBundleId.isEmpty ? null : _iosBundleId,
      );
    }
    throw UnsupportedError(
      'Shop Wave Firebase is configured for web, Android, and iOS only.',
    );
  }
}
