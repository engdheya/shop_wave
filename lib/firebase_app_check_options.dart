/// App Check web configuration is separate from FlutterFire's generated
/// Firebase options so `flutterfire configure` can regenerate that file safely.
class FirebaseAppCheckOptions {
  static const _recaptchaSiteKey =
      String.fromEnvironment('FIREBASE_RECAPTCHA_SITE_KEY');

  static String get reCaptchaSiteKey {
    if (_recaptchaSiteKey.isEmpty) {
      throw StateError('FIREBASE_RECAPTCHA_SITE_KEY is required for web App Check.');
    }
    return _recaptchaSiteKey;
  }
}
