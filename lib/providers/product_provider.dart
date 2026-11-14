import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/product.dart';

/// Read-only legacy catalog adapter. Public marketplace products now come from
/// Firestore; this provider never seeds sample data or writes catalog records.
class ProductProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  bool _isConnected = true;
  List<Product> _allProducts = [];
  List<Category> _categories = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSubscription;

  static const Map<String, String> _categoryIcons = {
    'smartphones': '📱',
    'audio': '🎧',
    'home': '🪴',
    'fashion': '🧵',
    'beauty': '🌿',
    'gaming': '🎮',
  };

  ProductProvider() {
    Future.microtask(_initializeData);
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _isConnected;
  List<Product> get allProducts => List.unmodifiable(_allProducts);
  List<Category> get categories => List.unmodifiable(_categories);

  Future<void> _initializeData() async {
    _isLoading = true;
    await _initConnectivity();
    _firestoreSubscription = FirebaseFirestore.instance
        .collection('products')
        .where('isActive', isEqualTo: true)
        .where('storeStatus', isEqualTo: 'active')
        .snapshots()
        .listen(
      (snapshot) {
        _allProducts = snapshot.docs.map(Product.fromDoc).toList(growable: false);
        _buildCategoriesFromProducts();
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('Firestore catalog stream failed: $error');
        _errorMessage = 'Marketplace catalog is temporarily unavailable.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _initConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _isConnected = !results.contains(ConnectivityResult.none);
    } catch (_) {
      _isConnected = true;
    }
  }

  /// Refreshes the server-backed read-only listing. Product mutations must go
  /// through the trusted marketplace Functions API.
  Future<void> fetchProducts({bool showOfflineMessage = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _initConnectivity();
      if (!_isConnected && showOfflineMessage) {
        _errorMessage = 'Connect to the internet to refresh the catalog.';
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('isActive', isEqualTo: true)
          .where('storeStatus', isEqualTo: 'active')
          .get();
      _allProducts = snapshot.docs.map(Product.fromDoc).toList(growable: false);
      _buildCategoriesFromProducts();
    } catch (error) {
      debugPrint('Could not refresh the Firebase catalog: $error');
      _errorMessage = 'Marketplace catalog is temporarily unavailable.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _buildCategoriesFromProducts() {
    final ids = _allProducts.map((product) => product.categoryId).toSet();
    _categories = ids.map((id) => Category(
      id: id,
      name: _formatCategoryName(id),
      icon: _categoryIcons[id] ?? '📦',
      imageUrl: '',
      productCount: _allProducts.where((product) => product.categoryId == id).length,
    )).toList(growable: false);
  }

  String _formatCategoryName(String id) => id
      .split(RegExp(r'[_ -]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  List<Product> getProductsByCategory(String categoryId) => _allProducts
      .where((product) => product.categoryId == categoryId)
      .toList(growable: false);

  Product? getProductById(String id) {
    for (final product in _allProducts) {
      if (product.id == id) return product;
    }
    return null;
  }

  void toggleFavorite(Product product) {
    product.isFavorite = !product.isFavorite;
    notifyListeners();
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }
}
