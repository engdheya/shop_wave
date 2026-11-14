import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/marketplace_models.dart';
import '../repositories/firebase_marketplace_repository.dart';
import '../models/product.dart';

class MarketplaceProvider extends ChangeNotifier {
  static const String _sampleSellerId = 'seller-nova';

  MarketplaceProvider({FirebaseMarketplaceRepository? repository})
      : _repository = repository {
    if (_repository == null) {
      // Kept only for isolated legacy/widget tests. Production constructs this
      // provider with FirebaseMarketplaceRepository and never loads seed data.
      _stores.addAll(_seedStores());
      _products.addAll(_seedProducts());
      _applications.addAll(_seedApplications());
    } else {
      _bindRemoteData();
    }
  }

  final FirebaseMarketplaceRepository? _repository;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  int _remoteGeneration = 0;
  final Map<String, MarketplaceStore> _publicStoreCache = {};
  final Map<String, MarketplaceStore> _ownedStoreCache = {};
  final Map<String, MarketplaceStore> _adminStoreCache = {};
  final Map<String, Product> _publicProductCache = {};
  final Map<String, Product> _ownedProductCache = {};
  final Map<String, Product> _adminProductCache = {};
  List<StoreOrder> _remoteSellerOrders = [];
  SellerApplication? _ownSellerApplication;

  final List<MarketplaceStore> _stores = [];
  final List<Product> _products = [];
  final List<SellerApplication> _applications = [];
  final List<MarketplaceOrder> _orders = [];
  final List<MarketplaceAuditEvent> _auditEvents = [];
  final Set<String> _favoriteIds = {};
  final Map<String, int> _cartQuantities = {};
  final Random _random = Random.secure();
  String? _checkoutRequestId;
  final List<String> _comparisonIds = [];

  MarketplaceRole _role = MarketplaceRole.customer;
  String? _activeUserId;
  String _activeUserName = '';
  String _activeUserPhone = '';
  String _sellerId = _sampleSellerId;
  bool _activeSellerApproved = true;
  String _query = '';
  String? _selectedCategoryId;
  String? _selectedStoreId;
  bool _onlyAvailable = false;
  double _minimumPrice = 0;
  double _maximumPrice = 2000;
  MarketplaceSort _sort = MarketplaceSort.featured;
  int _orderSequence = 0;
  int _productSequence = 0;

  MarketplaceRole get role => _role;
  bool get isAuthenticated => _activeUserId != null;
  String? get activeUserId => _activeUserId;
  bool get currentSellerApproved => _activeSellerApproved;
  SellerApplicationStatus? get currentSellerApplicationStatus {
    if (_role != MarketplaceRole.seller) return null;
    if (_repository != null) return _ownSellerApplication?.status;
    for (final application in _applications) {
      if (application.sellerId == _sellerId) return application.status;
    }
    return null;
  }
  String get query => _query;
  String? get selectedCategoryId => _selectedCategoryId;
  String? get selectedStoreId => _selectedStoreId;
  bool get onlyAvailable => _onlyAvailable;
  double get minimumPrice => _minimumPrice;
  double get maximumPrice => _maximumPrice;
  MarketplaceSort get sort => _sort;

  void _bindRemoteData() {
    final repository = _repository;
    if (repository == null) return;
    _remoteGeneration++;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _ownedStoreCache.clear();
    _adminStoreCache.clear();
    _ownedProductCache.clear();
    _adminProductCache.clear();
    _remoteSellerOrders = [];
    _ownSellerApplication = null;
    _orders.clear();
    _applications.clear();
    _auditEvents.clear();

    _listen<List<MarketplaceStore>>(repository.watchPublicStores(), (items) {
      _replaceCache(_publicStoreCache, items, (item) => item.id);
      _syncStores();
    });
    _listen<List<Product>>(repository.watchPublicProducts(), (items) {
      _replaceCache(_publicProductCache, items, (item) => item.id);
      _syncProducts();
    });

    if (_role == MarketplaceRole.seller && _activeUserId != null) {
      final sellerId = _activeUserId!;
      _listen<MarketplaceStore?>(repository.watchOwnedStore(sellerId), (store) {
        _ownedStoreCache.clear();
        if (store != null) _ownedStoreCache[store.id] = store;
        _syncStores();
      });
      _listen<List<Product>>(repository.watchOwnProducts(sellerId), (items) {
        _replaceCache(_ownedProductCache, items, (item) => item.id);
        _syncProducts();
      });
      _listen<SellerApplication?>(
        repository.watchSellerApplication(sellerId),
        (application) {
          _ownSellerApplication = application;
          notifyListeners();
        },
      );
      _listen<List<StoreOrder>>(
        repository.watchSellerOrders(sellerId),
        (orders) {
          _remoteSellerOrders = orders;
          notifyListeners();
        },
      );
    } else if (_role == MarketplaceRole.admin) {
      _listen<List<MarketplaceStore>>(repository.watchAdminStores(), (items) {
        _replaceCache(_adminStoreCache, items, (item) => item.id);
        _syncStores();
      });
      _listen<List<Product>>(repository.watchAdminProducts(), (items) {
        _replaceCache(_adminProductCache, items, (item) => item.id);
        _syncProducts();
      });
      _listen<List<SellerApplication>>(
        repository.watchAdminApplications(),
        (items) {
          _applications
            ..clear()
            ..addAll(items);
          notifyListeners();
        },
      );
      _listen<List<MarketplaceOrder>>(repository.watchAdminOrders(), (items) {
        _orders
          ..clear()
          ..addAll(items);
        notifyListeners();
      });
      _listen<List<MarketplaceAuditEvent>>(
        repository.watchAdminAuditEvents(),
        (items) {
          _auditEvents
            ..clear()
            ..addAll(items);
          notifyListeners();
        },
      );
    } else if (_role == MarketplaceRole.customer && _activeUserId != null) {
      _listen<List<MarketplaceOrder>>(
        repository.watchCustomerOrders(_activeUserId!),
        (items) {
          _orders
            ..clear()
            ..addAll(items);
          notifyListeners();
        },
      );
    }
    _syncStores();
    _syncProducts();
  }

  void _listen<T>(Stream<T> stream, void Function(T) onValue) {
    final generation = _remoteGeneration;
    _subscriptions.add(stream.listen(
      (value) {
        if (generation == _remoteGeneration) onValue(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation == _remoteGeneration) {
          debugPrint('Firebase marketplace stream failed: $error');
        }
      },
    ));
  }

  void _replaceCache<T>(Map<String, T> cache, Iterable<T> values, String Function(T) id) {
    cache
      ..clear()
      ..addEntries(values.map((value) => MapEntry(id(value), value)));
  }

  void _syncStores() {
    final merged = <String, MarketplaceStore>{
      ..._publicStoreCache,
      ..._ownedStoreCache,
      ..._adminStoreCache,
    };
    _stores
      ..clear()
      ..addAll(merged.values);
    notifyListeners();
  }

  void _syncProducts() {
    final merged = <String, Product>{
      ..._publicProductCache,
      ..._ownedProductCache,
      ..._adminProductCache,
    };
    _products
      ..clear()
      ..addAll(merged.values);
    notifyListeners();
  }

  List<MarketplaceCategory> get categories => const [
        MarketplaceCategory(
          id: 'smartphones',
          name: 'Phones',
          nameAr: 'هواتف',
          icon: '📱',
        ),
        MarketplaceCategory(
          id: 'audio',
          name: 'Audio',
          nameAr: 'صوتيات',
          icon: '🎧',
        ),
        MarketplaceCategory(
          id: 'home',
          name: 'Home',
          nameAr: 'المنزل',
          icon: '🪴',
        ),
        MarketplaceCategory(
          id: 'fashion',
          name: 'Fashion',
          nameAr: 'أزياء',
          icon: '🧵',
        ),
        MarketplaceCategory(
          id: 'beauty',
          name: 'Beauty',
          nameAr: 'جمال',
          icon: '🌿',
        ),
        MarketplaceCategory(
          id: 'gaming',
          name: 'Gaming',
          nameAr: 'ألعاب',
          icon: '🎮',
        ),
      ];

  List<MarketplaceStore> get stores => List.unmodifiable(_stores);

  List<MarketplaceStore> get activeStores => List.unmodifiable(
        _stores.where((store) => store.status == StoreStatus.active),
      );

  List<Product> get products => List.unmodifiable(_products);

  List<Product> get activeProducts => List.unmodifiable(
        _products.where((product) => product.isActive && _isStoreOpen(product.storeId)),
      );

  List<Product> get visibleProducts {
    final search = _query.trim().toLowerCase();
    final results = _products.where((product) {
      if (!product.isActive || !_isStoreOpen(product.storeId)) return false;
      if (_selectedCategoryId != null &&
          product.categoryId != _selectedCategoryId) {
        return false;
      }
      if (_selectedStoreId != null && product.storeId != _selectedStoreId) {
        return false;
      }
      if (product.price < _minimumPrice || product.price > _maximumPrice) {
        return false;
      }
      if (_onlyAvailable && !product.isAvailable) return false;
      if (search.isEmpty) return true;

      final store = storeById(product.storeId);
      final searchable = [
        product.name,
        product.nameAr,
        product.description,
        product.descriptionAr,
        product.categoryId,
        product.categoryAr,
        product.storeName,
        product.storeNameAr,
        product.sellerName,
        store?.name ?? '',
        store?.nameAr ?? '',
      ].join(' ').toLowerCase();
      return searchable.contains(search);
    }).toList();

    switch (_sort) {
      case MarketplaceSort.featured:
        results.sort((a, b) {
          final availability = (b.isAvailable ? 1 : 0) - (a.isAvailable ? 1 : 0);
          if (availability != 0) return availability;
          return b.rating.compareTo(a.rating);
        });
        break;
      case MarketplaceSort.priceLowToHigh:
        results.sort((a, b) => a.price.compareTo(b.price));
        break;
      case MarketplaceSort.priceHighToLow:
        results.sort((a, b) => b.price.compareTo(a.price));
        break;
      case MarketplaceSort.highestRated:
        results.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }
    return results;
  }

  List<MarketplaceStore> get matchingStores {
    final search = _query.trim().toLowerCase();
    return activeStores.where((store) {
      if (search.isEmpty) return true;
      return '${store.name} ${store.nameAr} ${store.description} ${store.descriptionAr} ${store.city}'
          .toLowerCase()
          .contains(search);
    }).toList();
  }

  List<Product> get comparedProducts => _comparisonIds
      .map(productById)
      .whereType<Product>()
      .toList(growable: false);

  int get comparisonCount => _comparisonIds.length;
  bool isCompared(Product product) => _comparisonIds.contains(product.id);

  List<Product> get favoriteProducts => _products
      .where((product) => _favoriteIds.contains(product.id))
      .toList(growable: false);

  bool isFavorite(Product product) => _favoriteIds.contains(product.id);

  List<MarketplaceCartLine> get cartLines => _cartQuantities.entries
      .map((entry) {
        final product = productById(entry.key);
        return product == null
            ? null
            : MarketplaceCartLine(product: product, quantity: entry.value);
      })
      .whereType<MarketplaceCartLine>()
      .toList(growable: false);

  List<CartStoreGroup> get cartGroups {
    final grouped = <String, List<MarketplaceCartLine>>{};
    for (final line in cartLines) {
      grouped.putIfAbsent(line.product.storeId, () => []).add(line);
    }

    return grouped.entries.map((entry) {
      final store = storeById(entry.key);
      if (store == null) return null;
      return CartStoreGroup(store: store, lines: entry.value);
    }).whereType<CartStoreGroup>().toList(growable: false);
  }

  int get cartItemCount => _cartQuantities.values.fold(0, (total, value) => total + value);
  int get cartStoreCount => cartGroups.length;
  double get cartSubtotal => cartLines.fold(0, (total, line) => total + line.total);

  List<MarketplaceOrder> get orders {
    if (_role == MarketplaceRole.admin) return List.unmodifiable(_orders);
    final userId = _activeUserId;
    if (userId == null || _role != MarketplaceRole.customer) return const [];
    return List.unmodifiable(_orders.where((order) => order.customerId == userId));
  }

  List<SellerApplication> get sellerApplications => _role == MarketplaceRole.admin
      ? List.unmodifiable(_applications)
      : const [];
  List<MarketplaceAuditEvent> get auditEvents => _role == MarketplaceRole.admin
      ? List.unmodifiable(_auditEvents.reversed)
      : const [];

  MarketplaceStore? get currentSellerStore {
    if (_role != MarketplaceRole.seller) return null;
    for (final store in _stores) {
      if (store.sellerId == _sellerId) return store;
    }
    return null;
  }

  List<Product> get currentSellerProducts => _role == MarketplaceRole.seller
      ? _products
          .where((product) => product.sellerId == _sellerId)
          .toList(growable: false)
      : const [];

  List<StoreOrder> get currentSellerOrders => _role != MarketplaceRole.seller
      ? const []
      : _repository != null
          ? List.unmodifiable(_remoteSellerOrders)
          : _orders
              .expand((order) => order.storeOrders)
              .where((order) => order.sellerId == _sellerId)
              .toList(growable: false);

  List<MarketplaceOrder> get allOrders => _role == MarketplaceRole.admin
      ? List.unmodifiable(_orders)
      : const [];
  int get pendingApplicationCount => _role == MarketplaceRole.admin
      ? _applications
          .where((item) => item.status == SellerApplicationStatus.pending)
          .length
      : 0;
  int get activeStoreCount => activeStores.length;
  int get catalogProductCount =>
      _products.where((product) => product.isActive).length;
  int get openOrderCount => _orders
      .expand((order) => order.storeOrders)
      .where((order) => order.status != StoreOrderStatus.completed &&
          order.status != StoreOrderStatus.cancelled &&
          order.status != StoreOrderStatus.declined)
      .length;
  double get demoSalesTotal => _role == MarketplaceRole.admin
      ? _orders
          .where((order) => order.paymentStatus == PaymentStatus.sandboxApproved)
          .fold(0, (total, order) => total + order.total)
      : 0;

  /// Local seed-data compatibility for tests only; production profiles and
  /// seller applications are loaded from Firebase streams.
  void restoreSellerAccounts(Iterable<MarketplaceUser> users) {
    if (_repository != null) return;
    for (final user in users) {
      if (user.role == MarketplaceRole.seller) _ensureSellerStore(user);
    }
    notifyListeners();
  }

  /// Synchronizes local UI capabilities with the verified Firebase profile.
  /// A null profile represents a browsing-only visitor.
  void setAuthenticatedUser(MarketplaceUser? user) {
    final nextUserId = user?.id;
    final nextRole = user?.role ?? MarketplaceRole.customer;
    final identityChanged = _activeUserId != nextUserId || _role != nextRole;
    final nextSellerApproved = user == null ||
        user.role != MarketplaceRole.seller ||
        user.sellerApproved;
    final remoteAccessChanged =
        identityChanged || _activeSellerApproved != nextSellerApproved;
    if (_activeUserId != null && identityChanged) {
      _cartQuantities.clear();
      _checkoutRequestId = null;
      _favoriteIds.clear();
      _comparisonIds.clear();
      for (final product in _products) {
        product.isFavorite = false;
      }
    }

    _activeUserId = nextUserId;
    _activeUserName = user?.displayName ?? '';
    _activeUserPhone = user?.phone ?? '';
    _role = user?.role ?? MarketplaceRole.customer;
    _selectedStoreId = null;
    _selectedCategoryId = null;

    if (user != null && user.role == MarketplaceRole.seller) {
      _sellerId = user.id;
      _activeSellerApproved = user.sellerApproved;
      if (_repository == null) _ensureSellerStore(user);
    } else {
      _sellerId = _sampleSellerId;
      _activeSellerApproved = true;
    }
    if (_repository != null && remoteAccessChanged) _bindRemoteData();
    notifyListeners();
  }

  void _ensureSellerStore(MarketplaceUser user) {
    if (_repository != null) return;
    if (user.storeName.trim().isEmpty) return;
    final storeId = user.storeId;
    final storeIndex = _stores.indexWhere((store) => store.id == storeId);
    final status = user.sellerApproved
        ? StoreStatus.active
        : user.sellerApplicationRejected
            ? StoreStatus.paused
            : StoreStatus.pending;
    final store = MarketplaceStore(
      id: storeId,
      sellerId: user.id,
      name: user.storeName,
      nameAr: user.storeName,
      description: user.storeDescription,
      descriptionAr: user.storeDescription,
      categoryId: user.storeCategoryId,
      city: user.storeCity,
      isVerified: user.sellerApproved,
      status: status,
    );
    if (storeIndex < 0) {
      _stores.add(store);
    } else {
      _stores[storeIndex] = _stores[storeIndex].copyWith(
        name: user.storeName,
        nameAr: user.storeName,
        description: user.storeDescription,
        descriptionAr: user.storeDescription,
        city: user.storeCity,
        isVerified: user.sellerApproved,
        status: status,
      );
    }

    final applicationId = 'application-${user.id}';
    final applicationIndex =
        _applications.indexWhere((application) => application.id == applicationId);
    final submittedAt = applicationIndex >= 0
        ? _applications[applicationIndex].submittedAt
        : DateTime.now();
    final application = SellerApplication(
      id: applicationId,
      sellerId: user.id,
      sellerName: user.displayName,
      storeName: user.storeName,
      categoryId: user.storeCategoryId,
      city: user.storeCity,
      note: user.storeDescription,
      submittedAt: submittedAt,
      status: user.sellerApproved
          ? SellerApplicationStatus.approved
          : user.sellerApplicationRejected
              ? SellerApplicationStatus.rejected
              : SellerApplicationStatus.pending,
    );
    if (applicationIndex < 0) {
      _applications.insert(0, application);
    } else {
      _applications[applicationIndex] = application;
    }
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setCategory(String? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setStoreFilter(String? storeId) {
    if (_selectedStoreId == storeId) return;
    _selectedStoreId = storeId;
    notifyListeners();
  }

  void setAvailabilityFilter(bool value) {
    if (_onlyAvailable == value) return;
    _onlyAvailable = value;
    notifyListeners();
  }

  void setPriceRange(double minimum, double maximum) {
    _minimumPrice = minimum < 0 ? 0 : minimum;
    _maximumPrice = maximum < _minimumPrice ? _minimumPrice : maximum;
    notifyListeners();
  }

  void setSort(MarketplaceSort value) {
    if (_sort == value) return;
    _sort = value;
    notifyListeners();
  }

  void clearFilters() {
    _query = '';
    _selectedCategoryId = null;
    _selectedStoreId = null;
    _onlyAvailable = false;
    _minimumPrice = 0;
    _maximumPrice = 2000;
    _sort = MarketplaceSort.featured;
    notifyListeners();
  }

  List<Product> productsForStore(String storeId, {bool includeInactive = false}) {
    final store = storeById(storeId);
    if (store == null || (!includeInactive && !store.isOpen)) return const [];
    return _products
        .where((product) =>
            product.storeId == storeId && (includeInactive || product.isActive))
        .toList(growable: false);
  }

  MarketplaceStore? storeById(String id) {
    for (final store in _stores) {
      if (store.id == id) return store;
    }
    return null;
  }

  Product? productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  MarketplaceOrder? orderById(String id) {
    for (final order in _orders) {
      if (order.id != id) continue;
      if (_role == MarketplaceRole.admin) return order;
      if (_role == MarketplaceRole.customer &&
          _activeUserId != null &&
          order.customerId == _activeUserId) {
        return order;
      }
      if (_role == MarketplaceRole.seller &&
          order.storeOrders.any((child) => child.sellerId == _sellerId)) {
        return order.copyWith(
          storeOrders: order.storeOrders
              .where((child) => child.sellerId == _sellerId)
              .toList(growable: false),
        );
      }
      return null;
    }
    return null;
  }

  void toggleFavorite(Product product) {
    if (!_favoriteIds.add(product.id)) _favoriteIds.remove(product.id);
    product.isFavorite = _favoriteIds.contains(product.id);
    notifyListeners();
  }

  CompareMutationResult toggleComparison(Product product) {
    if (_comparisonIds.contains(product.id)) {
      _comparisonIds.remove(product.id);
      notifyListeners();
      return CompareMutationResult.removed;
    }
    if (_comparisonIds.length >= 4) return CompareMutationResult.full;
    if (_comparisonIds.isNotEmpty &&
        comparedProducts.first.categoryId != product.categoryId) {
      return CompareMutationResult.differentCategory;
    }
    _comparisonIds.add(product.id);
    notifyListeners();
    return CompareMutationResult.added;
  }

  void removeFromComparison(String productId) {
    if (_comparisonIds.remove(productId)) notifyListeners();
  }

  void clearComparison() {
    if (_comparisonIds.isEmpty) return;
    _comparisonIds.clear();
    notifyListeners();
  }

  CartMutationResult addToCart(Product product) {
    final current = productById(product.id);
    if (current == null || !_canBuy(current)) {
      return CartMutationResult.unavailable;
    }
    final quantity = _cartQuantities[product.id] ?? 0;
    if (quantity >= current.stockQuantity) {
      return CartMutationResult.stockLimitReached;
    }
    _cartQuantities[product.id] = quantity + 1;
    _checkoutRequestId = null;
    notifyListeners();
    return CartMutationResult.success;
  }

  CartMutationResult setCartQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return CartMutationResult.success;
    }
    final product = productById(productId);
    if (product == null || !_canBuy(product)) return CartMutationResult.unavailable;
    if (quantity > product.stockQuantity) return CartMutationResult.stockLimitReached;
    _cartQuantities[productId] = quantity;
    _checkoutRequestId = null;
    notifyListeners();
    return CartMutationResult.success;
  }

  void removeFromCart(String productId) {
    if (_cartQuantities.remove(productId) != null) {
      _checkoutRequestId = null;
      notifyListeners();
    }
  }

  void clearCart() {
    if (_cartQuantities.isEmpty) return;
    _cartQuantities.clear();
    _checkoutRequestId = null;
    notifyListeners();
  }

  Future<CheckoutResult> placeOrder(CheckoutDetails details) async {
    if (_repository == null) return checkoutDemo(details);
    if (_role != MarketplaceRole.customer || _activeUserId == null) {
      return const CheckoutResult.failure('Sign in as a customer before checkout.');
    }
    if (_cartQuantities.isEmpty) {
      return const CheckoutResult.failure('Your cart is empty.');
    }
    try {
      _checkoutRequestId ??= _newCheckoutRequestId();
      final order = await _repository!.placeSandboxOrder(
        requestId: _checkoutRequestId!,
        cart: Map<String, int>.from(_cartQuantities),
        details: details,
      );
      _checkoutRequestId = null;
      _cartQuantities.clear();
      _recordAudit(_activeUserName, 'Created sandbox order', order.id);
      notifyListeners();
      return CheckoutResult.success(order);
    } catch (error) {
      debugPrint('Trusted sandbox order creation failed: $error');
      return const CheckoutResult.failure(
        'Checkout could not be completed. Check stock and try again.',
      );
    }
  }

  CheckoutResult checkoutDemo(CheckoutDetails details) {
    if (_role != MarketplaceRole.customer || _activeUserId == null) {
      return const CheckoutResult.failure('Sign in as a customer before checkout.');
    }
    if (_cartQuantities.isEmpty) {
      return const CheckoutResult.failure('Your cart is empty.');
    }

    for (final entry in _cartQuantities.entries) {
      final product = productById(entry.key);
      if (product == null || !_canBuy(product)) {
        return const CheckoutResult.failure(
          'A product or store is no longer available. Review your cart.',
        );
      }
      if (entry.value > product.stockQuantity) {
        return const CheckoutResult.failure(
          'Stock changed while you were shopping. Review item quantities.',
        );
      }
    }

    _orderSequence++;
    final parentId = 'SW-${DateTime.now().year}-${_orderSequence.toString().padLeft(4, '0')}';
    final createdAt = DateTime.now();
    final groupedLines = <String, List<MarketplaceOrderLine>>{};

    for (final entry in _cartQuantities.entries) {
      final product = productById(entry.key)!;
      groupedLines.putIfAbsent(product.storeId, () => []).add(
            MarketplaceOrderLine(
              productId: product.id,
              productName: product.name,
              productNameAr: product.nameAr,
              imageUrl: product.imageUrl,
              storeId: product.storeId,
              sellerId: product.sellerId,
              unitPrice: product.price,
              quantity: entry.value,
            ),
          );
    }

    final subOrders = groupedLines.entries.map((entry) {
      final store = storeById(entry.key)!;
      return StoreOrder(
        id: '$parentId-${store.id}',
        parentOrderId: parentId,
        storeId: store.id,
        sellerId: store.sellerId,
        status: StoreOrderStatus.awaitingSeller,
        lines: List.unmodifiable(entry.value),
        createdAt: createdAt,
      );
    }).toList(growable: false);

    final order = MarketplaceOrder(
      id: parentId,
      customerId: _activeUserId!,
      customerName: details.customerName.trim().isEmpty
          ? _activeUserName
          : details.customerName.trim(),
      customerPhone: details.customerPhone.trim().isEmpty
          ? _activeUserPhone
          : details.customerPhone.trim(),
      deliveryAddress: details.deliveryAddress.trim(),
      createdAt: createdAt,
      paymentStatus: PaymentStatus.sandboxApproved,
      storeOrders: subOrders,
    );

    for (final entry in _cartQuantities.entries) {
      final index = _products.indexWhere((product) => product.id == entry.key);
      final product = _products[index];
      _products[index] = product.copyWith(
        stockQuantity: product.stockQuantity - entry.value,
      );
    }
    _orders.insert(0, order);
    _cartQuantities.clear();
    _recordAudit(_activeUserName, 'Created sandbox order', parentId);
    notifyListeners();
    return CheckoutResult.success(order);
  }

  Future<bool> cancelStoreOrderRemote(String parentOrderId, String storeOrderId) async {
    if (_repository == null) return cancelStoreOrder(parentOrderId, storeOrderId);
    if (_role != MarketplaceRole.customer || _activeUserId == null) return false;
    try {
      await _repository!.call('transitionStoreOrder', {
        'orderId': parentOrderId,
        'storeOrderId': storeOrderId,
        'action': 'cancel',
      });
      return true;
    } catch (error) {
      debugPrint('Trusted order cancellation failed: $error');
      return false;
    }
  }

  bool cancelStoreOrder(String parentOrderId, String storeOrderId) {
    if (_role != MarketplaceRole.customer) return false;
    final parentIndex = _orders.indexWhere((order) => order.id == parentOrderId);
    if (parentIndex < 0) return false;
    final parent = _orders[parentIndex];
    if (_activeUserId == null || parent.customerId != _activeUserId) return false;
    final childIndex = parent.storeOrders.indexWhere((order) => order.id == storeOrderId);
    if (childIndex < 0 || !parent.storeOrders[childIndex].canCustomerCancel) {
      return false;
    }

    final child = parent.storeOrders[childIndex];
    for (final line in child.lines) {
      final productIndex = _products.indexWhere((product) => product.id == line.productId);
      if (productIndex >= 0) {
        final product = _products[productIndex];
        _products[productIndex] = product.copyWith(
          stockQuantity: product.stockQuantity + line.quantity,
        );
      }
    }

    final updatedChildren = List<StoreOrder>.from(parent.storeOrders);
    updatedChildren[childIndex] = child.copyWith(status: StoreOrderStatus.cancelled);
    _orders[parentIndex] = parent.copyWith(storeOrders: updatedChildren);
    _recordAudit(_activeUserName, 'Cancelled store order', storeOrderId);
    notifyListeners();
    return true;
  }

  Future<bool> advanceSellerOrderRemote(String parentOrderId, String storeOrderId) async {
    if (_repository == null) return advanceSellerOrder(parentOrderId, storeOrderId);
    if (_role != MarketplaceRole.seller) return false;
    try {
      await _repository!.call('transitionStoreOrder', {
        'orderId': parentOrderId,
        'storeOrderId': storeOrderId,
        'action': 'advance',
      });
      return true;
    } catch (error) {
      debugPrint('Trusted seller order update failed: $error');
      return false;
    }
  }

  bool advanceSellerOrder(String parentOrderId, String storeOrderId) {
    if (_role != MarketplaceRole.seller) return false;
    final parentIndex = _orders.indexWhere((order) => order.id == parentOrderId);
    if (parentIndex < 0) return false;
    final parent = _orders[parentIndex];
    final childIndex = parent.storeOrders.indexWhere((order) => order.id == storeOrderId);
    if (childIndex < 0) return false;
    final child = parent.storeOrders[childIndex];
    if (child.sellerId != _sellerId) return false;

    final nextStatus = switch (child.status) {
      StoreOrderStatus.awaitingSeller => StoreOrderStatus.accepted,
      StoreOrderStatus.accepted => StoreOrderStatus.preparing,
      StoreOrderStatus.preparing => StoreOrderStatus.ready,
      StoreOrderStatus.ready => StoreOrderStatus.completed,
      _ => null,
    };
    if (nextStatus == null) return false;

    final updatedChildren = List<StoreOrder>.from(parent.storeOrders);
    updatedChildren[childIndex] = child.copyWith(status: nextStatus);
    _orders[parentIndex] = parent.copyWith(storeOrders: updatedChildren);
    _recordAudit(_sellerId, 'Updated order to ${nextStatus.name}', storeOrderId);
    notifyListeners();
    return true;
  }

  String newProductId() =>
      _repository?.newProductId() ?? 'seller-product-${_productSequence + 1}';

  Future<bool> saveOwnProduct({
    String? productId,
    required String name,
    required double price,
    required int stockQuantity,
    required String categoryId,
    required String description,
    required String imageUrl,
    required bool isActive,
  }) async {
    if (_repository == null) {
      if (productId == null || productById(productId) == null) {
        return createOwnProduct(
          name: name,
          price: price,
          stockQuantity: stockQuantity,
          categoryId: categoryId,
          description: description,
          imageUrl: imageUrl,
        );
      }
      return updateOwnProduct(
        productId: productId,
        name: name,
        price: price,
        stockQuantity: stockQuantity,
        categoryId: categoryId,
        description: description,
        imageUrl: imageUrl,
        isActive: isActive,
      );
    }
    if (_role != MarketplaceRole.seller ||
        !_activeSellerApproved ||
        name.trim().isEmpty ||
        price < 0 ||
        stockQuantity < 0 ||
        currentSellerStore == null) {
      return false;
    }
    try {
      await _repository!.call('saveProduct', {
        if (productId != null) 'productId': productId,
        'name': name.trim(),
        'price': price,
        'stockQuantity': stockQuantity,
        'categoryId': categoryId,
        'description': description.trim(),
        'imageUrl': imageUrl.trim(),
        'isActive': isActive && stockQuantity > 0,
      });
      return true;
    } catch (error) {
      debugPrint('Trusted product save failed: $error');
      return false;
    }
  }

  bool updateOwnProduct({
    required String productId,
    required double price,
    required int stockQuantity,
    required bool isActive,
    String? name,
    String? description,
    String? imageUrl,
    String? categoryId,
  }) {
    if (_role != MarketplaceRole.seller ||
        price < 0 ||
        stockQuantity < 0 ||
        (name != null && name.trim().isEmpty)) {
      return false;
    }
    final index = _products.indexWhere((product) => product.id == productId);
    if (index < 0 || _products[index].sellerId != _sellerId) return false;
    final category = categoryId == null ? null : categoryById(categoryId);
    _products[index] = _products[index].copyWith(
      name: name?.trim(),
      description: description,
      imageUrl: imageUrl,
      categoryId: categoryId,
      categoryAr: category?.nameAr,
      price: price,
      stockQuantity: stockQuantity,
      isActive: isActive,
    );
    _recordAudit(_sellerId, 'Updated product and inventory', productId);
    notifyListeners();
    return true;
  }

  bool createOwnProduct({
    required String name,
    required double price,
    required int stockQuantity,
    required String categoryId,
    required String description,
    String imageUrl = '',
  }) {
    if (_role != MarketplaceRole.seller ||
        name.trim().isEmpty ||
        price < 0 ||
        stockQuantity < 0) {
      return false;
    }
    final store = currentSellerStore;
    if (store == null) return false;
    _productSequence++;
    _products.insert(
      0,
      Product(
        id: 'seller-product-$_productSequence',
        name: name.trim(),
        categoryId: categoryId,
        categoryAr: categoryById(categoryId)?.nameAr ?? '',
        price: price,
        imageUrl: imageUrl.trim(),
        description: description.trim(),
        rating: 0,
        storeId: store.id,
        storeName: store.name,
        storeNameAr: store.nameAr,
        sellerId: store.sellerId,
        sellerName: _activeUserName.isEmpty ? 'Store team' : _activeUserName,
        sellerNameAr: _activeUserName.isEmpty ? 'فريق المتجر' : _activeUserName,
        stockQuantity: stockQuantity,
        isActive: stockQuantity > 0,
      ),
    );
    _recordAudit(_sellerId, 'Created product', 'seller-product-$_productSequence');
    notifyListeners();
    return true;
  }

  Future<bool> setOwnStoreOpenRemote(bool isOpen) async {
    if (_repository == null) return setOwnStoreOpen(isOpen);
    if (_role != MarketplaceRole.seller || (isOpen && !_activeSellerApproved)) {
      return false;
    }
    try {
      await _repository!.call('setStoreAvailability', {'isOpen': isOpen});
      return true;
    } catch (error) {
      debugPrint('Trusted store availability update failed: $error');
      return false;
    }
  }

  bool setOwnStoreOpen(bool isOpen) {
    if (_role != MarketplaceRole.seller || (isOpen && !_activeSellerApproved)) {
      return false;
    }
    final index = _stores.indexWhere((store) => store.sellerId == _sellerId);
    if (index < 0) return false;
    _stores[index] = _stores[index].copyWith(
      status: isOpen ? StoreStatus.active : StoreStatus.paused,
    );
    _recordAudit(_sellerId, isOpen ? 'Opened store' : 'Paused store', _stores[index].id);
    notifyListeners();
    return true;
  }

  Future<bool> updateOwnStoreRemote({
    required String name,
    required String description,
    required String city,
    String logoUrl = '',
    String coverUrl = '',
  }) async {
    if (_repository == null) {
      return updateOwnStore(
        name: name,
        description: description,
        city: city,
        logoUrl: logoUrl,
        coverUrl: coverUrl,
      );
    }
    if (_role != MarketplaceRole.seller || name.trim().isEmpty) return false;
    try {
      await _repository!.call('updateStoreProfile', {
        'name': name.trim(),
        'description': description.trim(),
        'city': city.trim(),
        'logoUrl': logoUrl.trim(),
        'coverUrl': coverUrl.trim(),
      });
      return true;
    } catch (error) {
      debugPrint('Trusted store profile update failed: $error');
      return false;
    }
  }

  bool updateOwnStore({
    required String name,
    required String description,
    required String city,
    String logoUrl = '',
    String coverUrl = '',
  }) {
    if (_role != MarketplaceRole.seller || name.trim().isEmpty) return false;
    final index = _stores.indexWhere((store) => store.sellerId == _sellerId);
    if (index < 0) return false;
    _stores[index] = _stores[index].copyWith(
      name: name.trim(),
      nameAr: name.trim(),
      description: description.trim(),
      descriptionAr: description.trim(),
      city: city.trim().isEmpty ? _stores[index].city : city.trim(),
      logoUrl: logoUrl.isEmpty ? _stores[index].logoUrl : logoUrl.trim(),
      coverUrl: coverUrl.isEmpty ? _stores[index].coverUrl : coverUrl.trim(),
    );
    for (var productIndex = 0; productIndex < _products.length; productIndex++) {
      if (_products[productIndex].storeId == _stores[index].id) {
        _products[productIndex] = _products[productIndex].copyWith(
          storeName: _stores[index].name,
          storeNameAr: _stores[index].nameAr,
        );
      }
    }
    _recordAudit(_sellerId, 'Updated store profile', _stores[index].id);
    notifyListeners();
    return true;
  }

  Future<bool> reviewSellerApplicationRemote(
    String applicationId, {
    required bool approve,
  }) async {
    if (_repository == null) {
      return reviewSellerApplication(applicationId, approve: approve);
    }
    if (_role != MarketplaceRole.admin) return false;
    SellerApplication? application;
    for (final item in _applications) {
      if (item.id == applicationId) {
        application = item;
        break;
      }
    }
    if (application == null || application.status != SellerApplicationStatus.pending) {
      return false;
    }
    try {
      await _repository!.call('reviewSellerApplication', {
        'sellerId': application.sellerId,
        'approve': approve,
      });
      return true;
    } catch (error) {
      debugPrint('Trusted seller review failed: $error');
      return false;
    }
  }

  bool reviewSellerApplication(String applicationId, {required bool approve}) {
    if (_role != MarketplaceRole.admin) return false;
    final index = _applications.indexWhere((application) => application.id == applicationId);
    if (index < 0 || _applications[index].status != SellerApplicationStatus.pending) {
      return false;
    }
    final application = _applications[index];
    _applications[index] = application.copyWith(
      status: approve
          ? SellerApplicationStatus.approved
          : SellerApplicationStatus.rejected,
    );

    final storeIndex = _stores.indexWhere(
      (store) => store.sellerId == application.sellerId,
    );
    if (storeIndex >= 0) {
      _stores[storeIndex] = _stores[storeIndex].copyWith(
        isVerified: approve,
        status: approve ? StoreStatus.active : StoreStatus.paused,
      );
    } else if (approve) {
      _stores.add(
        MarketplaceStore(
          id: 'store-${application.id}',
          sellerId: application.sellerId,
          name: application.storeName,
          nameAr: application.storeName,
          description: application.note.isEmpty
              ? 'A new independent Shop Wave merchant.'
              : application.note,
          descriptionAr: application.note,
          categoryId: application.categoryId,
          city: application.city,
          rating: 5,
          reviewCount: 0,
          isVerified: true,
        ),
      );
    }
    if (_sellerId == application.sellerId) {
      _activeSellerApproved = approve;
    }
    _recordAudit('Platform admin', approve ? 'Approved seller' : 'Rejected seller', applicationId);
    notifyListeners();
    return true;
  }

  Future<bool> setStoreSuspendedRemote(
    String storeId, {
    required bool suspended,
  }) async {
    if (_repository == null) return setStoreSuspended(storeId, suspended: suspended);
    if (_role != MarketplaceRole.admin) return false;
    try {
      await _repository!.call('adminSetStoreStatus', {
        'storeId': storeId,
        'suspended': suspended,
      });
      return true;
    } catch (error) {
      debugPrint('Trusted store moderation failed: $error');
      return false;
    }
  }

  bool setStoreSuspended(String storeId, {required bool suspended}) {
    if (_role != MarketplaceRole.admin) return false;
    final index = _stores.indexWhere((store) => store.id == storeId);
    if (index < 0) return false;
    _stores[index] = _stores[index].copyWith(
      status: suspended ? StoreStatus.suspended : StoreStatus.active,
    );
    _recordAudit(
      'Platform admin',
      suspended ? 'Suspended store' : 'Reactivated store',
      storeId,
    );
    notifyListeners();
    return true;
  }

  Future<bool> setProductModerationRemote(
    String productId, {
    required bool visible,
  }) async {
    if (_repository == null) return setProductModeration(productId, visible: visible);
    if (_role != MarketplaceRole.admin) return false;
    try {
      await _repository!.call('adminSetProductVisibility', {
        'productId': productId,
        'visible': visible,
      });
      return true;
    } catch (error) {
      debugPrint('Trusted product moderation failed: $error');
      return false;
    }
  }

  bool setProductModeration(String productId, {required bool visible}) {
    if (_role != MarketplaceRole.admin) return false;
    final index = _products.indexWhere((product) => product.id == productId);
    if (index < 0) return false;
    _products[index] = _products[index].copyWith(isActive: visible);
    _recordAudit(
      'Platform admin',
      visible ? 'Restored product' : 'Hid product',
      productId,
    );
    notifyListeners();
    return true;
  }

  MarketplaceCategory? categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  String _newCheckoutRequestId() => 'sw-${List<int>.generate(
        48,
        (_) => _random.nextInt(16),
      ).map((value) => value.toRadixString(16)).join()}';

  void _recordAudit(String actor, String action, String target) {
    _auditEvents.add(
      MarketplaceAuditEvent(
        createdAt: DateTime.now(),
        actor: actor,
        action: action,
        target: target,
      ),
    );
  }

  bool _isStoreOpen(String storeId) => storeById(storeId)?.isOpen ?? false;

  bool _canBuy(Product product) =>
      product.isActive && product.stockQuantity > 0 && _isStoreOpen(product.storeId);

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  static List<MarketplaceStore> _seedStores() => [
        const MarketplaceStore(
          id: 'store-nova',
          sellerId: 'seller-nova',
          name: 'Nova Tech',
          nameAr: 'نوفا للتقنية',
          description: 'Smart devices, honest advice, and local after-care.',
          descriptionAr: 'أجهزة ذكية ونصائح موثوقة وخدمة محلية.',
          categoryId: 'smartphones',
          city: 'Aden',
          logoUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=320&h=320&fit=crop',
          coverUrl: 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=1200&h=500&fit=crop',
          rating: 4.9,
          reviewCount: 328,
        ),
        const MarketplaceStore(
          id: 'store-aden-mobile',
          sellerId: 'seller-aden-mobile',
          name: 'Aden Mobile',
          nameAr: 'عدن موبايل',
          description: 'Popular phones and accessories from a trusted local team.',
          descriptionAr: 'هواتف وإكسسوارات مختارة من فريق محلي موثوق.',
          categoryId: 'smartphones',
          city: 'Aden',
          logoUrl: 'https://images.unsplash.com/photo-1512499617640-c74ae3a79d37?w=320&h=320&fit=crop',
          coverUrl: 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=1200&h=500&fit=crop',
          rating: 4.7,
          reviewCount: 214,
        ),
        const MarketplaceStore(
          id: 'store-palm-loom',
          sellerId: 'seller-palm-loom',
          name: 'Palm & Loom',
          nameAr: 'نخلة ونسيج',
          description: 'Thoughtful home pieces made for everyday living.',
          descriptionAr: 'قطع منزلية جميلة وعملية للاستخدام اليومي.',
          categoryId: 'home',
          city: 'Taiz',
          logoUrl: 'https://images.unsplash.com/photo-1490312278390-ab64016e0aa9?w=320&h=320&fit=crop',
          coverUrl: 'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?w=1200&h=500&fit=crop',
          rating: 4.8,
          reviewCount: 176,
        ),
        const MarketplaceStore(
          id: 'store-threadline',
          sellerId: 'seller-threadline',
          name: 'Threadline Studio',
          nameAr: 'استوديو ثريدلاين',
          description: 'Small-batch clothing and accessories with a local point of view.',
          descriptionAr: 'ملابس وإكسسوارات بتصاميم محلية وإنتاج محدود.',
          categoryId: 'fashion',
          city: 'Aden',
          logoUrl: 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=320&h=320&fit=crop',
          coverUrl: 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=1200&h=500&fit=crop',
          rating: 4.6,
          reviewCount: 98,
        ),
        const MarketplaceStore(
          id: 'store-rawan-beauty',
          sellerId: 'seller-rawan',
          name: 'Rawan Botanics',
          nameAr: 'روان بوتانيكس',
          description: 'Skin and self-care essentials inspired by botanical ingredients.',
          descriptionAr: 'منتجات للعناية بالبشرة مستوحاة من المكونات الطبيعية.',
          categoryId: 'beauty',
          city: 'Sana’a',
          logoUrl: 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=320&h=320&fit=crop',
          coverUrl: 'https://images.unsplash.com/photo-1601049541289-9b1b7bbbfe19?w=1200&h=500&fit=crop',
          rating: 4.9,
          reviewCount: 145,
        ),
        const MarketplaceStore(
          id: 'store-pixel-hub',
          sellerId: 'seller-pixel',
          name: 'Pixel Hub',
          nameAr: 'بيكسل هَب',
          description: 'Consoles, gaming gear, and everything for your next session.',
          descriptionAr: 'أجهزة ألعاب وملحقات لكل جلسة لعب جديدة.',
          categoryId: 'gaming',
          city: 'Aden',
          logoUrl: 'https://images.unsplash.com/photo-1593305841991-05c297ba4575?w=320&h=320&fit=crop',
          coverUrl: 'https://images.unsplash.com/photo-1593305841991-05c297ba4575?w=1200&h=500&fit=crop',
          rating: 4.8,
          reviewCount: 187,
        ),
      ];

  static List<Product> _seedProducts() => [
        _product(
          id: 'p-iphone-16-pro',
          name: 'iPhone 16 Pro · 256 GB',
          nameAr: 'آيفون 16 برو · 256 جيجابايت',
          categoryId: 'smartphones',
          price: 1099,
          imageUrl: 'https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=800&fit=crop',
          description: 'A pro camera system, a bright display, and all-day performance.',
          descriptionAr: 'كاميرا احترافية وشاشة مشرقة وأداء يدوم طوال اليوم.',
          storeId: 'store-nova',
          storeName: 'Nova Tech',
          storeNameAr: 'نوفا للتقنية',
          sellerId: 'seller-nova',
          sellerName: 'Nova Tech team',
          sellerNameAr: 'فريق نوفا للتقنية',
          stock: 7,
          rating: 4.9,
          attributes: {'Storage': '256 GB', 'Display': '6.3 in', 'Warranty': '1 year'},
        ),
        _product(
          id: 'p-galaxy-s25',
          name: 'Galaxy S25 Ultra · 256 GB',
          nameAr: 'جالاكسي S25 ألترا · 256 جيجابايت',
          categoryId: 'smartphones',
          price: 999,
          imageUrl: 'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=800&fit=crop',
          description: 'A vivid display, long battery life, and a versatile camera.',
          descriptionAr: 'شاشة نابضة بالحياة وبطارية طويلة وكاميرا متعددة الاستخدامات.',
          storeId: 'store-aden-mobile',
          storeName: 'Aden Mobile',
          storeNameAr: 'عدن موبايل',
          sellerId: 'seller-aden-mobile',
          sellerName: 'Aden Mobile team',
          sellerNameAr: 'فريق عدن موبايل',
          stock: 5,
          rating: 4.8,
          attributes: {'Storage': '256 GB', 'Display': '6.8 in', 'Warranty': '1 year'},
        ),
        _product(
          id: 'p-pixel-9',
          name: 'Pixel 9 Pro · 128 GB',
          nameAr: 'بيكسل 9 برو · 128 جيجابايت',
          categoryId: 'smartphones',
          price: 849,
          imageUrl: 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=800&fit=crop',
          description: 'A clean Android experience with smart everyday photography.',
          descriptionAr: 'تجربة أندرويد سلسة وتصوير ذكي للحياة اليومية.',
          storeId: 'store-nova',
          storeName: 'Nova Tech',
          storeNameAr: 'نوفا للتقنية',
          sellerId: 'seller-nova',
          sellerName: 'Nova Tech team',
          sellerNameAr: 'فريق نوفا للتقنية',
          stock: 0,
          rating: 4.7,
          attributes: {'Storage': '128 GB', 'Display': '6.3 in', 'Warranty': '1 year'},
        ),
        _product(
          id: 'p-oneplus-13',
          name: 'OnePlus 13 · 256 GB',
          nameAr: 'ون بلس 13 · 256 جيجابايت',
          categoryId: 'smartphones',
          price: 779,
          imageUrl: 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=800&fit=crop',
          description: 'Fast charging and a smooth display in a refined design.',
          descriptionAr: 'شحن سريع وشاشة سلسة ضمن تصميم أنيق.',
          storeId: 'store-aden-mobile',
          storeName: 'Aden Mobile',
          storeNameAr: 'عدن موبايل',
          sellerId: 'seller-aden-mobile',
          sellerName: 'Aden Mobile team',
          sellerNameAr: 'فريق عدن موبايل',
          stock: 4,
          rating: 4.6,
          attributes: {'Storage': '256 GB', 'Display': '6.8 in', 'Warranty': '1 year'},
        ),
        _product(
          id: 'p-xiaomi-14',
          name: 'Xiaomi 14 · 256 GB',
          nameAr: 'شاومي 14 · 256 جيجابايت',
          categoryId: 'smartphones',
          price: 649,
          imageUrl: 'https://images.unsplash.com/photo-1605236453806-6ff36851218e?w=800&fit=crop',
          description: 'A compact flagship with a crisp screen and fast performance.',
          descriptionAr: 'هاتف رائد بحجم مدمج وشاشة واضحة وأداء سريع.',
          storeId: 'store-nova',
          storeName: 'Nova Tech',
          storeNameAr: 'نوفا للتقنية',
          sellerId: 'seller-nova',
          sellerName: 'Nova Tech team',
          sellerNameAr: 'فريق نوفا للتقنية',
          stock: 3,
          rating: 4.5,
          attributes: {'Storage': '256 GB', 'Display': '6.4 in', 'Warranty': '1 year'},
        ),
        _product(
          id: 'p-sonic-headphones',
          name: 'Sonic Pro Wireless Headphones',
          nameAr: 'سونيك برو سماعات لاسلكية',
          categoryId: 'audio',
          price: 149,
          oldPrice: 179,
          discountPercentage: 17,
          imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800&fit=crop',
          description: 'Comfortable over-ear listening with rich, balanced sound.',
          descriptionAr: 'استماع مريح وصوت متوازن وغني.',
          storeId: 'store-nova',
          storeName: 'Nova Tech',
          storeNameAr: 'نوفا للتقنية',
          sellerId: 'seller-nova',
          sellerName: 'Nova Tech team',
          sellerNameAr: 'فريق نوفا للتقنية',
          stock: 12,
          rating: 4.8,
          attributes: {'Battery': '30 hours', 'Connection': 'Bluetooth 5.3', 'Warranty': '1 year'},
        ),
        _product(
          id: 'p-studio-buds',
          name: 'Studio Buds Wireless Earbuds',
          nameAr: 'سماعات ستوديو بودز لاسلكية',
          categoryId: 'audio',
          price: 89,
          imageUrl: 'https://images.unsplash.com/photo-1606220945770-b5b6c2c55bf1?w=800&fit=crop',
          description: 'Pocket-sized earbuds with a secure fit and clear calls.',
          descriptionAr: 'سماعات صغيرة بثبات مريح ومكالمات واضحة.',
          storeId: 'store-aden-mobile',
          storeName: 'Aden Mobile',
          storeNameAr: 'عدن موبايل',
          sellerId: 'seller-aden-mobile',
          sellerName: 'Aden Mobile team',
          sellerNameAr: 'فريق عدن موبايل',
          stock: 8,
          rating: 4.4,
          attributes: {'Battery': '24 hours', 'Connection': 'Bluetooth 5.2', 'Warranty': '6 months'},
        ),
        _product(
          id: 'p-ceramic-lamp',
          name: 'Hand-finished Ceramic Lamp',
          nameAr: 'مصباح خزفي بتشطيب يدوي',
          categoryId: 'home',
          price: 64,
          imageUrl: 'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?w=800&fit=crop',
          description: 'A warm, sculptural accent for a bedside table or reading nook.',
          descriptionAr: 'قطعة أنيقة بإضاءة دافئة لطاولة جانبية أو ركن القراءة.',
          storeId: 'store-palm-loom',
          storeName: 'Palm & Loom',
          storeNameAr: 'نخلة ونسيج',
          sellerId: 'seller-palm-loom',
          sellerName: 'Palm & Loom makers',
          sellerNameAr: 'حرفيو نخلة ونسيج',
          stock: 6,
          rating: 4.9,
          attributes: {'Material': 'Ceramic', 'Finish': 'Hand-glazed', 'Care': 'Wipe clean'},
        ),
        _product(
          id: 'p-woven-rug',
          name: 'Woven Cotton Accent Rug',
          nameAr: 'سجادة قطنية منسوجة',
          categoryId: 'home',
          price: 98,
          imageUrl: 'https://images.unsplash.com/photo-1600166898405-da9535204843?w=800&fit=crop',
          description: 'A soft woven layer that brings texture to small spaces.',
          descriptionAr: 'طبقة ناعمة تضيف ملمساً جميلاً للمساحات الصغيرة.',
          storeId: 'store-palm-loom',
          storeName: 'Palm & Loom',
          storeNameAr: 'نخلة ونسيج',
          sellerId: 'seller-palm-loom',
          sellerName: 'Palm & Loom makers',
          sellerNameAr: 'حرفيو نخلة ونسيج',
          stock: 3,
          rating: 4.7,
          attributes: {'Material': 'Cotton', 'Size': '120 × 180 cm', 'Care': 'Spot clean'},
        ),
        _product(
          id: 'p-table-vase',
          name: 'Sculpted Stoneware Vase',
          nameAr: 'مزهرية حجرية منحوتة',
          categoryId: 'home',
          price: 42,
          imageUrl: 'https://images.unsplash.com/photo-1578500494198-246f612d3b3d?w=800&fit=crop',
          description: 'A small-batch stoneware vase with a tactile matte glaze.',
          descriptionAr: 'مزهرية خزفية بإنتاج محدود وملمس مطفي مميز.',
          storeId: 'store-palm-loom',
          storeName: 'Palm & Loom',
          storeNameAr: 'نخلة ونسيج',
          sellerId: 'seller-palm-loom',
          sellerName: 'Palm & Loom makers',
          sellerNameAr: 'حرفيو نخلة ونسيج',
          stock: 0,
          rating: 4.6,
          attributes: {'Material': 'Stoneware', 'Height': '22 cm', 'Care': 'Hand wash'},
        ),
        _product(
          id: 'p-linen-shirt',
          name: 'Relaxed Linen Shirt',
          nameAr: 'قميص كتان بقصة مريحة',
          categoryId: 'fashion',
          price: 55,
          imageUrl: 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=800&fit=crop',
          description: 'An easy everyday layer cut from breathable linen blend.',
          descriptionAr: 'قطعة يومية مريحة من مزيج كتان يسمح بمرور الهواء.',
          storeId: 'store-threadline',
          storeName: 'Threadline Studio',
          storeNameAr: 'استوديو ثريدلاين',
          sellerId: 'seller-threadline',
          sellerName: 'Threadline Studio',
          sellerNameAr: 'استوديو ثريدلاين',
          stock: 9,
          rating: 4.6,
          attributes: {'Material': 'Linen blend', 'Fit': 'Relaxed', 'Care': 'Cold wash'},
        ),
        _product(
          id: 'p-everyday-tote',
          name: 'Everyday Canvas Tote',
          nameAr: 'حقيبة قماش يومية',
          categoryId: 'fashion',
          price: 28,
          imageUrl: 'https://images.unsplash.com/photo-1590874103328-eac38a683ce7?w=800&fit=crop',
          description: 'A sturdy canvas carry-all for errands and daily essentials.',
          descriptionAr: 'حقيبة قماش متينة للاستخدام اليومي وحمل الاحتياجات الأساسية.',
          storeId: 'store-threadline',
          storeName: 'Threadline Studio',
          storeNameAr: 'استوديو ثريدلاين',
          sellerId: 'seller-threadline',
          sellerName: 'Threadline Studio',
          sellerNameAr: 'استوديو ثريدلاين',
          stock: 14,
          rating: 4.5,
          attributes: {'Material': 'Heavy canvas', 'Capacity': '18 L', 'Care': 'Spot clean'},
        ),
        _product(
          id: 'p-botanical-serum',
          name: 'Botanical Glow Face Serum',
          nameAr: 'سيروم إشراقة نباتي للوجه',
          categoryId: 'beauty',
          price: 32,
          imageUrl: 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=800&fit=crop',
          description: 'A lightweight daily serum made for a simple skin-care routine.',
          descriptionAr: 'سيروم يومي خفيف لروتين عناية بسيط بالبشرة.',
          storeId: 'store-rawan-beauty',
          storeName: 'Rawan Botanics',
          storeNameAr: 'روان بوتانيكس',
          sellerId: 'seller-rawan',
          sellerName: 'Rawan Botanics team',
          sellerNameAr: 'فريق روان بوتانيكس',
          stock: 10,
          rating: 4.9,
          attributes: {'Volume': '30 ml', 'Skin type': 'All skin types', 'Made in': 'Yemen'},
        ),
        _product(
          id: 'p-citrus-mist',
          name: 'Citrus & Neroli Body Mist',
          nameAr: 'رذاذ جسم بالحمضيات والنيرولي',
          categoryId: 'beauty',
          price: 24,
          imageUrl: 'https://images.unsplash.com/photo-1594035910387-fea47794261f?w=800&fit=crop',
          description: 'A light fresh fragrance for a quick everyday refresh.',
          descriptionAr: 'رائحة منعشة وخفيفة للاستخدام اليومي.',
          storeId: 'store-rawan-beauty',
          storeName: 'Rawan Botanics',
          storeNameAr: 'روان بوتانيكس',
          sellerId: 'seller-rawan',
          sellerName: 'Rawan Botanics team',
          sellerNameAr: 'فريق روان بوتانيكس',
          stock: 7,
          rating: 4.7,
          attributes: {'Volume': '100 ml', 'Fragrance': 'Citrus', 'Made in': 'Yemen'},
        ),
        _product(
          id: 'p-mechanical-keyboard',
          name: 'Aurora Mechanical Keyboard',
          nameAr: 'لوحة مفاتيح ميكانيكية أورورا',
          categoryId: 'gaming',
          price: 119,
          imageUrl: 'https://images.unsplash.com/photo-1595225476474-87563907a212?w=800&fit=crop',
          description: 'Tactile switches, a compact layout, and adjustable lighting.',
          descriptionAr: 'مفاتيح لمسية وحجم مدمج وإضاءة قابلة للتعديل.',
          storeId: 'store-pixel-hub',
          storeName: 'Pixel Hub',
          storeNameAr: 'بيكسل هَب',
          sellerId: 'seller-pixel',
          sellerName: 'Pixel Hub team',
          sellerNameAr: 'فريق بيكسل هَب',
          stock: 6,
          rating: 4.8,
          attributes: {'Layout': '75%', 'Switches': 'Tactile', 'Connection': 'USB-C'},
        ),
        _product(
          id: 'p-gamepad',
          name: 'Wireless Pro Controller',
          nameAr: 'وحدة تحكم لاسلكية برو',
          categoryId: 'gaming',
          price: 74,
          imageUrl: 'https://images.unsplash.com/photo-1600080972464-8e5f35f63d08?w=800&fit=crop',
          description: 'Responsive controls and a comfortable grip for long sessions.',
          descriptionAr: 'تحكم سريع وقبضة مريحة لجلسات اللعب الطويلة.',
          storeId: 'store-pixel-hub',
          storeName: 'Pixel Hub',
          storeNameAr: 'بيكسل هَب',
          sellerId: 'seller-pixel',
          sellerName: 'Pixel Hub team',
          sellerNameAr: 'فريق بيكسل هَب',
          stock: 11,
          rating: 4.7,
          attributes: {'Connection': 'Wireless', 'Battery': '20 hours', 'Warranty': '1 year'},
        ),
        _product(
          id: 'p-gaming-headset',
          name: 'Cloud Gaming Headset',
          nameAr: 'سماعة ألعاب كلاود',
          categoryId: 'gaming',
          price: 95,
          imageUrl: 'https://images.unsplash.com/photo-1593508512255-86ab42a8e620?w=800&fit=crop',
          description: 'Clear chat audio and a lightweight frame for comfortable play.',
          descriptionAr: 'صوت واضح للمحادثات وتصميم خفيف للعب براحة.',
          storeId: 'store-pixel-hub',
          storeName: 'Pixel Hub',
          storeNameAr: 'بيكسل هَب',
          sellerId: 'seller-pixel',
          sellerName: 'Pixel Hub team',
          sellerNameAr: 'فريق بيكسل هَب',
          stock: 4,
          rating: 4.6,
          attributes: {'Connection': 'USB / 3.5 mm', 'Microphone': 'Detachable', 'Warranty': '1 year'},
        ),
      ];

  static Product _product({
    required String id,
    required String name,
    required String nameAr,
    required String categoryId,
    required double price,
    required String imageUrl,
    required String description,
    required String descriptionAr,
    required String storeId,
    required String storeName,
    required String storeNameAr,
    required String sellerId,
    required String sellerName,
    required String sellerNameAr,
    required int stock,
    required double rating,
    required Map<String, String> attributes,
    double? oldPrice,
    int? discountPercentage,
  }) {
    final category = _categorySeed.firstWhere((item) => item.id == categoryId);
    return Product(
      id: id,
      name: name,
      nameAr: nameAr,
      categoryId: categoryId,
      categoryAr: category.nameAr,
      price: price,
      oldPrice: oldPrice,
      discountPercentage: discountPercentage,
      imageUrl: imageUrl,
      description: description,
      descriptionAr: descriptionAr,
      rating: rating,
      storeId: storeId,
      storeName: storeName,
      storeNameAr: storeNameAr,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerNameAr: sellerNameAr,
      stockQuantity: stock,
      attributes: attributes,
    );
  }

  static const List<MarketplaceCategory> _categorySeed = [
    MarketplaceCategory(id: 'smartphones', name: 'Phones', nameAr: 'هواتف', icon: '📱'),
    MarketplaceCategory(id: 'audio', name: 'Audio', nameAr: 'صوتيات', icon: '🎧'),
    MarketplaceCategory(id: 'home', name: 'Home', nameAr: 'المنزل', icon: '🪴'),
    MarketplaceCategory(id: 'fashion', name: 'Fashion', nameAr: 'أزياء', icon: '🧵'),
    MarketplaceCategory(id: 'beauty', name: 'Beauty', nameAr: 'جمال', icon: '🌿'),
    MarketplaceCategory(id: 'gaming', name: 'Gaming', nameAr: 'ألعاب', icon: '🎮'),
  ];

  static List<SellerApplication> _seedApplications() => [
        SellerApplication(
          id: 'application-pending-01',
          sellerId: 'seller-applicant-maha',
          sellerName: 'Maha Saleh',
          storeName: 'Aden Artisan House',
          categoryId: 'home',
          city: 'Aden',
          note: 'Handmade home decor by independent local makers.',
          submittedAt: DateTime(2026, 11, 11),
        ),
        SellerApplication(
          id: 'application-pending-02',
          sellerId: 'seller-applicant-hatem',
          sellerName: 'Hatem Al-Qadhi',
          storeName: 'Harbor Outdoor',
          categoryId: 'gaming',
          city: 'Aden',
          note: 'Outdoor and recreational gear from a family-run shop.',
          submittedAt: DateTime(2026, 11, 13),
        ),
      ];
}
