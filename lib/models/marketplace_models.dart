import 'package:cloud_firestore/cloud_firestore.dart';

import 'product.dart';

enum MarketplaceRole { customer, seller, admin }

enum MarketplaceSort { featured, priceLowToHigh, priceHighToLow, highestRated }

/// Local marketplace identity used by the prototype auth flow.
/// Password material is deliberately kept in the auth provider, not this model.
class MarketplaceUser {
  final String id;
  final String username;
  final String email;
  final String displayName;
  final String phone;
  final MarketplaceRole role;
  final String storeName;
  final String storeCategoryId;
  final String storeCity;
  final String storeDescription;
  final bool sellerApproved;
  final bool sellerApplicationRejected;

  const MarketplaceUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.phone = '',
    this.role = MarketplaceRole.customer,
    this.storeName = '',
    this.storeCategoryId = 'home',
    this.storeCity = 'Aden',
    this.storeDescription = '',
    this.sellerApproved = false,
    this.sellerApplicationRejected = false,
  });

  String get storeId => 'store-$id';

  MarketplaceUser copyWith({
    MarketplaceRole? role,
    String? storeName,
    String? storeCategoryId,
    String? storeCity,
    String? storeDescription,
    bool? sellerApproved,
    bool? sellerApplicationRejected,
  }) {
    return MarketplaceUser(
      id: id,
      username: username,
      email: email,
      displayName: displayName,
      phone: phone,
      role: role ?? this.role,
      storeName: storeName ?? this.storeName,
      storeCategoryId: storeCategoryId ?? this.storeCategoryId,
      storeCity: storeCity ?? this.storeCity,
      storeDescription: storeDescription ?? this.storeDescription,
      sellerApproved: sellerApproved ?? this.sellerApproved,
      sellerApplicationRejected:
          sellerApplicationRejected ?? this.sellerApplicationRejected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'displayName': displayName,
        'phone': phone,
        'role': role.name,
        'storeName': storeName,
        'storeCategoryId': storeCategoryId,
        'storeCity': storeCity,
        'storeDescription': storeDescription,
        'sellerApproved': sellerApproved,
        'sellerApplicationRejected': sellerApplicationRejected,
      };

  factory MarketplaceUser.fromJson(Map<String, dynamic> json) {
    final roleName = json['role'] as String?;
    final role = MarketplaceRole.values.firstWhere(
      (value) => value.name == roleName,
      orElse: () => MarketplaceRole.customer,
    );
    return MarketplaceUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: role,
      storeName: json['storeName']?.toString() ?? '',
      storeCategoryId: json['storeCategoryId']?.toString() ?? 'home',
      storeCity: json['storeCity']?.toString() ?? 'Aden',
      storeDescription: json['storeDescription']?.toString() ?? '',
      sellerApproved: json['sellerApproved'] == true,
      sellerApplicationRejected: json['sellerApplicationRejected'] == true,
    );
  }
}

enum StoreStatus { active, pending, paused, suspended }

enum SellerApplicationStatus { pending, approved, rejected }

enum StoreOrderStatus {
  awaitingSeller,
  accepted,
  preparing,
  ready,
  completed,
  cancelled,
  declined,
}

enum PaymentStatus { sandboxApproved, pending, failed }

enum CartMutationResult { success, unavailable, stockLimitReached }

enum CompareMutationResult { added, removed, full, differentCategory }

class MarketplaceCategory {
  final String id;
  final String name;
  final String nameAr;
  final String icon;

  const MarketplaceCategory({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.icon,
  });
}

class MarketplaceStore {
  final String id;
  final String sellerId;
  final String name;
  final String nameAr;
  final String description;
  final String descriptionAr;
  final String categoryId;
  final String city;
  final String logoUrl;
  final String coverUrl;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final StoreStatus status;

  const MarketplaceStore({
    required this.id,
    required this.sellerId,
    required this.name,
    this.nameAr = '',
    required this.description,
    this.descriptionAr = '',
    required this.categoryId,
    this.city = 'Aden',
    this.logoUrl = '',
    this.coverUrl = '',
    this.rating = 4.8,
    this.reviewCount = 0,
    this.isVerified = true,
    this.status = StoreStatus.active,
  });

  bool get isOpen => status == StoreStatus.active;

  Map<String, dynamic> toJson() => {
        'sellerId': sellerId,
        'name': name,
        'nameAr': nameAr,
        'description': description,
        'descriptionAr': descriptionAr,
        'categoryId': categoryId,
        'city': city,
        'logoUrl': logoUrl,
        'coverUrl': coverUrl,
        'rating': rating,
        'reviewCount': reviewCount,
        'isVerified': isVerified,
        'status': status.name,
      };

  factory MarketplaceStore.fromJson(
    String id,
    Map<String, dynamic> json,
  ) => MarketplaceStore(
        id: id,
        sellerId: _string(json['sellerId']),
        name: _string(json['name']),
        nameAr: _string(json['nameAr']),
        description: _string(json['description']),
        descriptionAr: _string(json['descriptionAr']),
        categoryId: _string(json['categoryId'], 'home'),
        city: _string(json['city'], 'Aden'),
        logoUrl: _string(json['logoUrl']),
        coverUrl: _string(json['coverUrl']),
        rating: _number(json['rating'], 0),
        reviewCount: _integer(json['reviewCount'], 0),
        isVerified: json['isVerified'] == true,
        status: StoreStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => StoreStatus.pending,
        ),
      );

  MarketplaceStore copyWith({

    String? name,
    String? nameAr,
    String? description,
    String? descriptionAr,
    String? city,
    String? logoUrl,
    String? coverUrl,
    bool? isVerified,
    StoreStatus? status,
  }) {
    return MarketplaceStore(
      id: id,
      sellerId: sellerId,
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      description: description ?? this.description,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      categoryId: categoryId,
      city: city ?? this.city,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      rating: rating,
      reviewCount: reviewCount,
      isVerified: isVerified ?? this.isVerified,
      status: status ?? this.status,
    );
  }
}

class SellerApplication {
  final String id;
  final String sellerId;
  final String sellerName;
  final String storeName;
  final String categoryId;
  final String city;
  final String note;
  final DateTime submittedAt;
  final SellerApplicationStatus status;

  const SellerApplication({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.storeName,
    required this.categoryId,
    required this.city,
    this.note = '',
    required this.submittedAt,
    this.status = SellerApplicationStatus.pending,
  });

  Map<String, dynamic> toJson() => {
        'sellerId': sellerId,
        'sellerName': sellerName,
        'storeName': storeName,
        'categoryId': categoryId,
        'city': city,
        'note': note,
        'submittedAt': submittedAt.toIso8601String(),
        'status': status.name,
      };

  factory SellerApplication.fromJson(
    String id,
    Map<String, dynamic> json,
  ) => SellerApplication(
        id: id,
        sellerId: _string(json['sellerId']),
        sellerName: _string(json['sellerName']),
        storeName: _string(json['storeName']),
        categoryId: _string(json['categoryId'], 'home'),
        city: _string(json['city'], 'Aden'),
        note: _string(json['note']),
        submittedAt: _date(json['submittedAt']),
        status: SellerApplicationStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => SellerApplicationStatus.pending,
        ),
      );

  SellerApplication copyWith({SellerApplicationStatus? status}) {
    return SellerApplication(
      id: id,
      sellerId: sellerId,
      sellerName: sellerName,
      storeName: storeName,
      categoryId: categoryId,
      city: city,
      note: note,
      submittedAt: submittedAt,
      status: status ?? this.status,
    );
  }
}

class MarketplaceCartLine {
  final Product product;
  final int quantity;

  const MarketplaceCartLine({required this.product, required this.quantity});

  double get total => product.price * quantity;
}

class CartStoreGroup {
  final MarketplaceStore store;
  final List<MarketplaceCartLine> lines;

  const CartStoreGroup({required this.store, required this.lines});

  double get subtotal => lines.fold(0, (total, line) => total + line.total);
}

class MarketplaceOrderLine {
  final String productId;
  final String productName;
  final String productNameAr;
  final String imageUrl;
  final String storeId;
  final String sellerId;
  final double unitPrice;
  final int quantity;

  const MarketplaceOrderLine({
    required this.productId,
    required this.productName,
    required this.productNameAr,
    required this.imageUrl,
    required this.storeId,
    required this.sellerId,
    required this.unitPrice,
    required this.quantity,
  });

  double get total => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'productNameAr': productNameAr,
        'imageUrl': imageUrl,
        'storeId': storeId,
        'sellerId': sellerId,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };

  factory MarketplaceOrderLine.fromJson(Map<String, dynamic> json) =>
      MarketplaceOrderLine(
        productId: _string(json['productId']),
        productName: _string(json['productName']),
        productNameAr: _string(json['productNameAr']),
        imageUrl: _string(json['imageUrl']),
        storeId: _string(json['storeId']),
        sellerId: _string(json['sellerId']),
        unitPrice: _number(json['unitPrice'], 0),
        quantity: _integer(json['quantity'], 0),
      );
}

class StoreOrder {
  final String id;
  final String parentOrderId;
  final String storeId;
  final String sellerId;
  final StoreOrderStatus status;
  final List<MarketplaceOrderLine> lines;
  final DateTime createdAt;

  const StoreOrder({
    required this.id,
    required this.parentOrderId,
    required this.storeId,
    required this.sellerId,
    required this.status,
    required this.lines,
    required this.createdAt,
  });

  double get subtotal => lines.fold(0, (total, line) => total + line.total);

  bool get canCustomerCancel =>
      status == StoreOrderStatus.awaitingSeller ||
      status == StoreOrderStatus.accepted;

  Map<String, dynamic> toJson() => {
        'id': id,
        'parentOrderId': parentOrderId,
        'storeId': storeId,
        'sellerId': sellerId,
        'status': status.name,
        'lines': lines.map((line) => line.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory StoreOrder.fromJson(
    String id,
    Map<String, dynamic> json,
  ) => StoreOrder(
        id: id,
        parentOrderId: _string(json['parentOrderId'] ?? json['orderId']),
        storeId: _string(json['storeId']),
        sellerId: _string(json['sellerId']),
        status: StoreOrderStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => StoreOrderStatus.awaitingSeller,
        ),
        lines: (json['lines'] as List? ?? const [])
            .whereType<Map>()
            .map((value) => MarketplaceOrderLine.fromJson(
                  Map<String, dynamic>.from(value),
                ))
            .toList(growable: false),
        createdAt: _date(json['createdAt']),
      );

  StoreOrder copyWith({StoreOrderStatus? status}) {
    return StoreOrder(
      id: id,
      parentOrderId: parentOrderId,
      storeId: storeId,
      sellerId: sellerId,
      status: status ?? this.status,
      lines: lines,
      createdAt: createdAt,
    );
  }
}

class MarketplaceOrder {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final DateTime createdAt;
  final PaymentStatus paymentStatus;
  final List<StoreOrder> storeOrders;

  const MarketplaceOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.createdAt,
    required this.paymentStatus,
    required this.storeOrders,
  });

  double get total =>
      storeOrders.fold(0, (amount, order) => amount + order.subtotal);

  int get itemCount => storeOrders.fold(
        0,
        (count, order) =>
            count + order.lines.fold(0, (lineCount, line) => lineCount + line.quantity),
      );

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'deliveryAddress': deliveryAddress,
        'createdAt': createdAt.toIso8601String(),
        'paymentStatus': paymentStatus.name,
        'storeOrderIds': storeOrders.map((order) => order.id).toList(),
      };

  factory MarketplaceOrder.fromJson(
    String id,
    Map<String, dynamic> json, {
    List<StoreOrder> storeOrders = const [],
  }) => MarketplaceOrder(
        id: id,
        customerId: _string(json['customerId']),
        customerName: _string(json['customerName']),
        customerPhone: _string(json['customerPhone']),
        deliveryAddress: _string(json['deliveryAddress']),
        createdAt: _date(json['createdAt']),
        paymentStatus: PaymentStatus.values.firstWhere(
          (value) => value.name == json['paymentStatus'],
          orElse: () => PaymentStatus.pending,
        ),
        storeOrders: storeOrders,
      );

  MarketplaceOrder copyWith({List<StoreOrder>? storeOrders}) {
    return MarketplaceOrder(
      id: id,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      createdAt: createdAt,
      paymentStatus: paymentStatus,
      storeOrders: storeOrders ?? this.storeOrders,
    );
  }
}

class CheckoutDetails {
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;

  const CheckoutDetails({
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
  });
}

class CheckoutResult {
  final MarketplaceOrder? order;
  final String? error;

  const CheckoutResult.success(MarketplaceOrder value)
      : order = value,
        error = null;

  const CheckoutResult.failure(this.error) : order = null;

  bool get isSuccess => order != null;
}

class MarketplaceAuditEvent {
  final DateTime createdAt;
  final String actor;
  final String action;
  final String target;

  const MarketplaceAuditEvent({
    required this.createdAt,
    required this.actor,
    required this.action,
    required this.target,
  });
}

String _string(Object? value, [String fallback = '']) =>
    value == null ? fallback : value.toString();

double _number(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? fallback;

int _integer(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? fallback;

DateTime _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
