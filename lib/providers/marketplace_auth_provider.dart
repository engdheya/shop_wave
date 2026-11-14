import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/marketplace_models.dart';
import '../repositories/firebase_marketplace_repository.dart';
import 'marketplace_provider.dart';

class MarketplaceAuthResult {
  final MarketplaceUser? user;
  final String? errorCode;

  const MarketplaceAuthResult._({this.user, this.errorCode});

  const MarketplaceAuthResult.success(MarketplaceUser value)
      : this._(user: value);

  const MarketplaceAuthResult.failure(String code)
      : this._(errorCode: code);

  bool get isSuccess => user != null;
}

/// Firebase Authentication session/profile adapter. User roles and seller
/// approval are read from server-owned Firestore documents and custom claims;
/// this client never grants itself a role.
class MarketplaceAuthProvider extends ChangeNotifier {
  static const String adminUsername = 'admin';

  final MarketplaceProvider _marketplace;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMarketplaceRepository _repository;
  late final Future<void> ready;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSubscription;
  int _userLoadGeneration = 0;

  MarketplaceUser? _currentUser;
  bool _isInitialized = false;
  String? _sessionError;

  MarketplaceAuthProvider(
    this._marketplace, {
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseMarketplaceRepository? repository,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _repository = repository ?? FirebaseMarketplaceRepository() {
    ready = _restoreSession();
  }

  MarketplaceUser? get currentUser => _currentUser;
  bool get isAuthenticated => _auth.currentUser != null && _currentUser != null;
  bool get isInitialized => _isInitialized;
  bool get isAdmin => _currentUser?.role == MarketplaceRole.admin;
  String? get sessionError => _sessionError;

  Future<void> _restoreSession() async {
    try {
      await _loadUser(_auth.currentUser);
      _authSubscription = _auth.userChanges().listen(
        (user) => _loadUser(user),
        onError: (Object error) {
          _sessionError = 'auth_state_error';
          debugPrint('Firebase Auth state stream failed: $error');
          _isInitialized = true;
          notifyListeners();
        },
      );
    } catch (error) {
      _sessionError = 'firebase_unavailable';
      debugPrint('Could not restore Firebase session: $error');
      _isInitialized = true;
    }
    notifyListeners();
  }

  Future<void> _loadUser(User? firebaseUser) async {
    final generation = ++_userLoadGeneration;
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    if (generation != _userLoadGeneration) return;
    _sessionError = null;
    if (firebaseUser == null) {
      _currentUser = null;
      _marketplace.setAuthenticatedUser(null);
      _isInitialized = true;
      notifyListeners();
      return;
    }

    try {
      final token = await firebaseUser.getIdTokenResult();
      final claims = token.claims ?? const <String, dynamic>{};
      final reference = _firestore.collection('users').doc(firebaseUser.uid);
      final snapshot = await reference.get();
      if (generation != _userLoadGeneration) return;
      if (!snapshot.exists) {
        _currentUser = null;
        _marketplace.setAuthenticatedUser(null);
        _sessionError = 'profile_unavailable';
        _isInitialized = true;
        notifyListeners();
        return;
      }
      var currentClaims = claims;
      var currentProfile = snapshot.data()!;
      var refreshingSellerClaims = false;
      _applyProfile(firebaseUser, currentClaims, currentProfile);
      _profileSubscription = reference.snapshots().listen((profile) {
        if (generation != _userLoadGeneration) return;
        if (!profile.exists || profile.data() == null) {
          _currentUser = null;
          _marketplace.setAuthenticatedUser(null);
          _sessionError = 'profile_unavailable';
          notifyListeners();
          return;
        }
        currentProfile = profile.data()!;
        _applyProfile(firebaseUser, currentClaims, currentProfile);
        notifyListeners();
        if (currentProfile['sellerApproved'] == true &&
            currentClaims['sellerApproved'] != true &&
            !refreshingSellerClaims) {
          refreshingSellerClaims = true;
          unawaited(_refreshSellerClaims(firebaseUser).then((refreshedClaims) {
            refreshingSellerClaims = false;
            if (refreshedClaims == null || generation != _userLoadGeneration) {
              return;
            }
            currentClaims = refreshedClaims;
            _applyProfile(firebaseUser, currentClaims, currentProfile);
            notifyListeners();
          }));
        }
      }, onError: (Object error) {
        if (generation == _userLoadGeneration) {
          debugPrint('Firebase user profile stream failed: $error');
        }
      });
      _isInitialized = true;
      notifyListeners();
    } catch (error) {
      if (generation != _userLoadGeneration) return;
      _currentUser = null;
      _marketplace.setAuthenticatedUser(null);
      _sessionError = 'profile_unavailable';
      debugPrint('Could not load Firebase user profile: $error');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> _refreshSellerClaims(
    User firebaseUser,
  ) async {
    try {
      final token = await firebaseUser.getIdTokenResult(true);
      return token.claims ?? const <String, dynamic>{};
    } catch (error) {
      debugPrint('Could not refresh seller approval claims: $error');
      return null;
    }
  }

  void _applyProfile(
    User firebaseUser,
    Map<String, dynamic> claims,
    Map<String, dynamic> data,
  ) {
    final role = claims['admin'] == true
        ? MarketplaceRole.admin
        : MarketplaceRole.values.firstWhere(
            (value) => value.name == data['role'],
            orElse: () => MarketplaceRole.customer,
          );
    final user = MarketplaceUser(
      id: firebaseUser.uid,
      username: _asString(data['username']),
      email: firebaseUser.email ?? _asString(data['email']),
      displayName: _asString(data['displayName'], firebaseUser.displayName ?? ''),
      phone: _asString(data['phone'], firebaseUser.phoneNumber ?? ''),
      role: role,
      storeName: _asString(data['storeName']),
      storeCategoryId: _asString(data['storeCategoryId'], 'home'),
      storeCity: _asString(data['storeCity'], 'Aden'),
      storeDescription: _asString(data['storeDescription']),
      sellerApproved: claims['seller'] == true &&
          claims['sellerApproved'] == true,
      sellerApplicationRejected: data['sellerApplicationRejected'] == true,
    );
    _currentUser = user;
    _marketplace.setAuthenticatedUser(user);
  }

  Future<MarketplaceAuthResult> signIn({
    required String identifier,
    required String password,
  }) async {
    await ready;
    final normalized = identifier.trim();
    if (normalized.isEmpty || password.isEmpty) {
      return const MarketplaceAuthResult.failure('invalid_credentials');
    }
    try {
      if (normalized.contains('@')) {
        await _auth.signInWithEmailAndPassword(
          email: normalized.toLowerCase(),
          password: password,
        );
      } else {
        final response = await _repository.call('signInWithUsername', {
          'username': normalized.toLowerCase(),
          'password': password,
        });
        final token = response['customToken']?.toString() ?? '';
        if (token.isEmpty) {
          return const MarketplaceAuthResult.failure('invalid_credentials');
        }
        await _auth.signInWithCustomToken(token);
      }
      await _loadUser(_auth.currentUser);
      final user = _currentUser;
      return user == null
          ? const MarketplaceAuthResult.failure('profile_unavailable')
          : MarketplaceAuthResult.success(user);
    } on FirebaseAuthException catch (error) {
      return MarketplaceAuthResult.failure(_authErrorCode(error.code));
    } on FirebaseFunctionsException catch (error) {
      return MarketplaceAuthResult.failure(_functionErrorCode(error));
    } catch (error) {
      debugPrint('Firebase sign-in failed: $error');
      return const MarketplaceAuthResult.failure('firebase_unavailable');
    }
  }

  Future<MarketplaceAuthResult> registerCustomer({
    required String displayName,
    required String username,
    required String email,
    required String password,
    String phone = '',
  }) => _register(
        role: MarketplaceRole.customer,
        displayName: displayName,
        username: username,
        email: email,
        password: password,
        phone: phone,
      );

  Future<MarketplaceAuthResult> registerSeller({
    required String displayName,
    required String username,
    required String email,
    required String password,
    String phone = '',
    required String storeName,
    required String storeCategoryId,
    required String storeCity,
    String storeDescription = '',
  }) => _register(
        role: MarketplaceRole.seller,
        displayName: displayName,
        username: username,
        email: email,
        password: password,
        phone: phone,
        storeName: storeName,
        storeCategoryId: storeCategoryId,
        storeCity: storeCity,
        storeDescription: storeDescription,
      );

  Future<MarketplaceAuthResult> _register({
    required MarketplaceRole role,
    required String displayName,
    required String username,
    required String email,
    required String password,
    required String phone,
    String storeName = '',
    String storeCategoryId = 'home',
    String storeCity = 'Aden',
    String storeDescription = '',
  }) async {
    await ready;
    final name = displayName.trim();
    final normalizedUsername = username.trim().toLowerCase();
    final normalizedEmail = email.trim().toLowerCase();
    if (name.length < 2) {
      return const MarketplaceAuthResult.failure('invalid_name');
    }
    if (!RegExp(r'^[a-z0-9_.-]{3,24}$').hasMatch(normalizedUsername) ||
        normalizedUsername == adminUsername) {
      return const MarketplaceAuthResult.failure('invalid_username');
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(normalizedEmail)) {
      return const MarketplaceAuthResult.failure('invalid_email');
    }
    if (password.length < 8) {
      return const MarketplaceAuthResult.failure('weak_password');
    }
    if (role == MarketplaceRole.seller && storeName.trim().length < 2) {
      return const MarketplaceAuthResult.failure('invalid_store');
    }

    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      await _repository.call('registerMarketplaceUser', {
        'username': normalizedUsername,
        'displayName': name,
        'phone': phone.trim(),
        'role': role.name,
        'storeName': storeName.trim(),
        'storeCategoryId': storeCategoryId,
        'storeCity': storeCity.trim().isEmpty ? 'Aden' : storeCity.trim(),
        'storeDescription': storeDescription.trim(),
      });
      await _loadUser(_auth.currentUser);
      final user = _currentUser;
      return user == null
          ? const MarketplaceAuthResult.failure('profile_unavailable')
          : MarketplaceAuthResult.success(user);
    } on FirebaseAuthException catch (error) {
      return MarketplaceAuthResult.failure(_authErrorCode(error.code));
    } on FirebaseFunctionsException catch (error) {
      final recovered = await _recoverCompletedRegistration(credential);
      if (recovered != null) return MarketplaceAuthResult.success(recovered);
      try {
        await credential?.user?.delete();
      } catch (_) {
        // The auth account remains unusable without the trusted user profile.
      }
      return MarketplaceAuthResult.failure(_functionErrorCode(error));
    } catch (error) {
      debugPrint('Firebase account registration failed: $error');
      final recovered = await _recoverCompletedRegistration(credential);
      if (recovered != null) return MarketplaceAuthResult.success(recovered);
      try {
        await credential?.user?.delete();
      } catch (_) {
        // Best-effort cleanup; no client-created profile is granted.
      }
      return const MarketplaceAuthResult.failure('firebase_unavailable');
    }
  }

  Future<MarketplaceUser?> _recoverCompletedRegistration(
    UserCredential? credential,
  ) async {
    final user = credential?.user;
    if (user == null) return null;
    try {
      final profile = await _firestore.collection('users').doc(user.uid).get();
      if (!profile.exists) return null;
      await _loadUser(user);
      return _currentUser;
    } catch (error) {
      debugPrint('Could not verify a retried Firebase registration: $error');
      return null;
    }
  }

  Future<MarketplaceAuthResult> applyForSeller({
    required String storeName,
    required String storeCategoryId,
    required String storeCity,
    String storeDescription = '',
  }) async {
    await ready;
    if (_currentUser == null || _currentUser!.role != MarketplaceRole.customer) {
      return const MarketplaceAuthResult.failure('sign_in_required');
    }
    if (storeName.trim().length < 2) {
      return const MarketplaceAuthResult.failure('invalid_store');
    }
    try {
      await _repository.call('applyForSeller', {
        'storeName': storeName.trim(),
        'storeCategoryId': storeCategoryId,
        'storeCity': storeCity.trim().isEmpty ? 'Aden' : storeCity.trim(),
        'storeDescription': storeDescription.trim(),
      });
      await _loadUser(_auth.currentUser);
      return _currentUser == null
          ? const MarketplaceAuthResult.failure('profile_unavailable')
          : MarketplaceAuthResult.success(_currentUser!);
    } on FirebaseFunctionsException catch (error) {
      return MarketplaceAuthResult.failure(_functionErrorCode(error));
    } catch (error) {
      debugPrint('Seller application failed: $error');
      return const MarketplaceAuthResult.failure('firebase_unavailable');
    }
  }

  Future<bool> updateCurrentSellerStore({
    required String storeName,
    required String storeDescription,
    required String storeCity,
  }) async {
    await ready;
    if (_currentUser?.role != MarketplaceRole.seller) return false;
    try {
      await _repository.call('updateStoreProfile', {
        'name': storeName.trim(),
        'description': storeDescription.trim(),
        'city': storeCity.trim(),
      });
      await _loadUser(_auth.currentUser);
      return true;
    } catch (error) {
      debugPrint('Store profile update failed: $error');
      return false;
    }
  }

  /// Admin approval is performed by the trusted function invoked by the
  /// marketplace provider; this method is retained only for API compatibility.
  Future<void> setSellerApproval(String sellerId, {required bool approved}) async {
    await ready;
    await _repository.call('reviewSellerApplication', {
      'sellerId': sellerId,
      'approve': approved,
    });
    await _auth.currentUser?.getIdToken(true);
    await _loadUser(_auth.currentUser);
  }

  Future<void> signOut() async {
    await ready;
    await _auth.signOut();
    _currentUser = null;
    _marketplace.setAuthenticatedUser(null);
    notifyListeners();
  }

  static String _authErrorCode(String code) {
    if (const {
      'invalid-credential',
      'wrong-password',
      'user-not-found',
      'invalid-email',
    }.contains(code)) {
      return 'invalid_credentials';
    }
    if (code == 'email-already-in-use') return 'email_taken';
    if (code == 'weak-password') return 'weak_password';
    return 'firebase_unavailable';
  }

  static String _functionErrorCode(FirebaseFunctionsException error) {
    final details = error.details;
    if (details is Map && details['errorCode'] is String) {
      return details['errorCode'] as String;
    }
    return switch (error.code) {
      'already-exists' => 'username_taken',
      'unauthenticated' => 'sign_in_required',
      'permission-denied' => 'not_authorized',
      'invalid-argument' => 'invalid_store',
      'not-found' => 'profile_unavailable',
      _ => 'firebase_unavailable',
    };
  }

  static String _asString(Object? value, [String fallback = '']) =>
      value == null ? fallback : value.toString();

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
