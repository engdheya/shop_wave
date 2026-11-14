# Shop Wave

Shop Wave is an Arabic-first, responsive multi-vendor marketplace. Visitors can browse the public catalog. Registration, sessions, seller approval, marketplace records, and image storage are designed around Firebase. **This repository does not yet identify a confirmed production Firebase project, and nothing here has been deployed. It is not launch-ready until the project-specific setup and deployment checklist below is completed and verified.**

## User flows

- **Visitor:** browse/search/filter active stores and products, compare up to four products from one category, and build a cart without signing in.
- **Customer:** register or sign in with email or username; authenticated checkout asks the trusted backend to validate the cart, recheck live prices/stock/store approval, reserve inventory, and create one order with store-specific suborders.
- **Seller:** register a store application, then manage the seller-owned store and listings after approval. Image uploads use Firebase Storage. Order state changes are validated by callable Cloud Functions.
- **Platform administrator:** the admin dashboard is enabled only by a trusted Firebase Authentication custom claim. No administrator password or client-side role switch is included.
- **Payment:** checkout is explicitly a **demo-only sandbox record**. It does not collect payment credentials, charge a customer, or represent a completed real payment integration.
- **Language and layout:** Arabic RTL by default, English toggle, responsive phone/tablet/desktop layouts.

## Firebase backend included in this repository

- Firebase Authentication for email/password credentials and sessions; username sign-in resolves and verifies credentials in a callable function without exposing the username-to-email index to clients.
- Cloud Firestore for user profiles, username reservations, seller applications, stores, products, customer orders, seller-scoped order documents, and admin audit events.
- Firebase Storage upload service and image picker for seller product photos and store logo/cover photos.
- Cloud Functions using the Admin SDK for account-profile creation, seller applications/reviews, store/product mutations, moderation, order transitions, and transactional inventory/order creation.
- `firestore.rules` and `storage.rules` deny client writes to marketplace records. Customers can read only their orders; sellers can read only their separate seller-scoped order documents. Roles and approval are not writable from the app.

The seed catalog and local mutator methods remain only as compatibility fixtures for isolated tests. The production app starts with Firebase and fails closed when project configuration is absent; it does not fall back to local users, sample catalog data, or demo administrator credentials.

## Configure a Firebase project before running

Choose the real Firebase project, platform app IDs, Firestore region, Storage bucket, Auth providers, and billing/security configuration with the project owner. Do not use a copied or guessed project ID. The previously committed Android `google-services.json` identifies `e-commerce-app-d84a1`; verify that it is the intended project and matches the other platform app IDs before deployment. Replace all platform Firebase configuration together if it is not the selected project.

1. Install Flutter/Dart, Node.js 20, Firebase CLI, and FlutterFire CLI. From the project root, run FlutterFire configuration for the selected project and supported platforms (this generates `lib/firebase_options.dart`), or copy `firebase.config.example.json` to the ignored local file `firebase.config.json` and fill it with that project's public client configuration. The example contains placeholders only.
2. For the JSON configuration, run with `--dart-define-from-file=firebase.config.json`. For FlutterFire-generated options, provide the web App Check site key separately with `--dart-define=FIREBASE_RECAPTCHA_SITE_KEY=YOUR_RECAPTCHA_SITE_KEY` on web builds. For example:

   ```bash
   flutter pub get
   flutter run -d chrome --dart-define-from-file=firebase.config.json
   # Or, after flutterfire configure:
   flutter run -d chrome --dart-define=FIREBASE_RECAPTCHA_SITE_KEY=YOUR_RECAPTCHA_SITE_KEY
   ```

   Native builds also need matching generated native Firebase files (including Android `google-services.json` and iOS `GoogleService-Info.plist`). Never commit service-account credentials.
3. Select the Firebase project in the Firebase CLI (`firebase use --add`). Create `functions/.env.<project-id>` containing the Firebase Web API key as `FIREBASE_WEB_API_KEY=...`; this is used by the username sign-in function to ask Firebase Authentication to verify the submitted password. The local env file is ignored by Git.
4. Enable Firebase Authentication Email/Password, create Firestore and Storage in the same selected project, and configure authorized domains. In Firebase Console App Check, register each app with web reCAPTCHA v3, Android Play Integrity, and iOS App Attest (Device Check fallback); provide the web site key as `FIREBASE_RECAPTCHA_SITE_KEY`. Register the debug tokens emitted by local Android/iOS debug builds, then verify provider metrics before deploying because every callable Function enforces App Check. Choose production region and indexes before accepting live users; the included Functions use `us-central1` and may be changed together with the client Functions region to match the project.
5. Install backend dependencies and deploy the rules, indexes, Storage rules, and functions:

   ```bash
   cd functions && npm install && npm run lint
   cd ..
   firebase deploy --only firestore:rules,firestore:indexes,storage,functions
   ```

6. Register a normal Shop Wave account. In a trusted environment with Application Default Credentials and the selected project explicitly set, provision the administrator claim for that account (never from the app):

   ```bash
   GOOGLE_CLOUD_PROJECT=<project-id> ADMIN_EMAIL=<registered-admin-email> \
     node functions/scripts/provision-admin.js
   ```

   The administrator must sign out and back in or refresh their Firebase ID token. Protect the admin mailbox, restrict IAM access to this script, and record the provisioning action.
7. Run Flutter analysis/tests, Firebase Emulator Suite rules/function tests, and real-platform smoke tests for registration, username/email sign-in, seller approval/rejection, Storage ownership, concurrent stock contention, cancellations, and role isolation. Do not enable real payments until a separate payment provider, webhook verification, refunds, reconciliation, and compliance review are implemented.

`firebase.json`, rules, and Functions are source configuration only; they do not create or deploy a Firebase project. Do not deploy until the selected project, region, Android/iOS/web apps, rules, indexes, and API-key restrictions have been reviewed.

## Run and test

After Firebase configuration and dependency resolution:

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=firebase.config.json
flutter test
flutter analyze
```

Backend JavaScript syntax check:

```bash
cd functions && npm run lint
```

Firestore and Storage rules tests (requires Firebase CLI and the emulators):

```bash
cd functions && npm install
cd ..
firebase emulators:exec --only firestore,storage "npm --prefix functions run test:rules"
```

The test suite denies client-side role/product/order writes, checks customer-versus-seller order isolation, and exercises approved-owner Storage uploads. Flutter tests and end-to-end Function/emulator tests still need to be run in an environment with Flutter/Dart and the Firebase Emulator Suite. No production deployment has been performed from this workspace.
