import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String nameAr;
  final String categoryId;
  final String categoryAr;
  final double price;
  final double? oldPrice;
  final int? discountPercentage;
  final String? timeLeft;
  final String imageUrl;
  final String description;
  final String descriptionAr;
  final double rating;
  final String storeId;
  final String storeName;
  final String storeNameAr;
  final String sellerId;
  final String sellerName;
  final String sellerNameAr;
  final int stockQuantity;
  final bool isActive;
  final Map<String, String> attributes;
  bool isFavorite;

  Product({
    required this.id,
    required this.name,
    this.nameAr = '',
    required this.categoryId,
    this.categoryAr = '',
    required this.price,
    this.oldPrice,
    this.discountPercentage,
    this.timeLeft,
    required this.imageUrl,
    this.description = '',
    this.descriptionAr = '',
    this.rating = 4.5,
    this.storeId = 'independent-store',
    this.storeName = 'Independent Store',
    this.storeNameAr = 'متجر مستقل',
    this.sellerId = 'independent-seller',
    this.sellerName = 'Independent seller',
    this.sellerNameAr = 'بائع مستقل',
    this.stockQuantity = 12,
    this.isActive = true,
    this.attributes = const {},
    this.isFavorite = false,
  });

  bool get isAvailable => isActive && stockQuantity > 0;

  String displayName({required bool arabic}) =>
      arabic && nameAr.isNotEmpty ? nameAr : name;

  String displayDescription({required bool arabic}) =>
      arabic && descriptionAr.isNotEmpty ? descriptionAr : description;

  String displayStoreName({required bool arabic}) =>
      arabic && storeNameAr.isNotEmpty ? storeNameAr : storeName;

  Product copyWith({
    String? name,
    String? nameAr,
    String? categoryId,
    String? categoryAr,
    double? price,
    double? oldPrice,
    String? imageUrl,
    String? description,
    String? descriptionAr,
    double? rating,
    String? storeId,
    String? storeName,
    String? storeNameAr,
    String? sellerId,
    String? sellerName,
    String? sellerNameAr,
    int? stockQuantity,
    bool? isActive,
    Map<String, String>? attributes,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      categoryId: categoryId ?? this.categoryId,
      categoryAr: categoryAr ?? this.categoryAr,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      timeLeft: timeLeft ?? this.timeLeft,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      rating: rating ?? this.rating,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      storeNameAr: storeNameAr ?? this.storeNameAr,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerNameAr: sellerNameAr ?? this.sellerNameAr,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isActive: isActive ?? this.isActive,
      attributes: attributes ?? this.attributes,
      isFavorite: isFavorite,
    );
  }

  /// Converts a product to JSON for a local cache or a demo catalog.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': name,
      'nameAr': nameAr,
      'price': price,
      'image': imageUrl,
      'category': categoryId,
      'categoryAr': categoryAr,
      'oldPrice': oldPrice,
      'discountPercentage': discountPercentage,
      'timeLeft': timeLeft,
      'description': description,
      'descriptionAr': descriptionAr,
      'rating': rating,
      'storeId': storeId,
      'storeName': storeName,
      'storeNameAr': storeNameAr,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerNameAr': sellerNameAr,
      'stockQuantity': stockQuantity,
      'isActive': isActive,
      'attributes': attributes,
      'isFavorite': isFavorite,
    };
  }

  /// Parses products from the local cache and compatible sample APIs.
  factory Product.fromJson(Map<String, dynamic> json) {
    final ratingValue = json['rating'];
    final rating = ratingValue is Map
        ? _asDouble(ratingValue['rate'], 4.5)
        : _asDouble(ratingValue, 4.5);

    return Product(
      id: _asString(json['id']),
      name: _asString(json['title'] ?? json['name'], 'Unknown Product'),
      nameAr: _asString(json['nameAr']),
      categoryId: _asString(json['categoryId'] ?? json['category'], 'others'),
      categoryAr: _asString(json['categoryAr']),
      price: _asDouble(json['price'], 0),
      imageUrl: _asString(json['imageUrl'] ?? json['image']),
      description: _asString(json['description']),
      descriptionAr: _asString(json['descriptionAr']),
      rating: rating,
      oldPrice: json['oldPrice'] == null
          ? null
          : _asDouble(json['oldPrice'], 0),
      discountPercentage: json['discountPercentage'] == null
          ? null
          : _asInt(json['discountPercentage']),
      timeLeft: json['timeLeft']?.toString(),
      storeId: _asString(json['storeId'], 'independent-store'),
      storeName: _asString(json['storeName'], 'Independent Store'),
      storeNameAr: _asString(json['storeNameAr'], 'متجر مستقل'),
      sellerId: _asString(json['sellerId'], 'independent-seller'),
      sellerName: _asString(json['sellerName'], 'Independent seller'),
      sellerNameAr: _asString(json['sellerNameAr'], 'بائع مستقل'),
      stockQuantity: _asInt(json['stockQuantity'], 12),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      attributes: _asStringMap(json['attributes']),
      isFavorite: json['isFavorite'] is bool
          ? json['isFavorite'] as bool
          : false,
    );
  }

  /// Converts a product to a Firestore-friendly map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nameAr': nameAr,
      'categoryId': categoryId,
      'categoryAr': categoryAr,
      'price': price,
      'oldPrice': oldPrice,
      'discountPercentage': discountPercentage,
      'timeLeft': timeLeft,
      'imageUrl': imageUrl,
      'description': description,
      'descriptionAr': descriptionAr,
      'rating': rating,
      'storeId': storeId,
      'storeName': storeName,
      'storeNameAr': storeNameAr,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerNameAr': sellerNameAr,
      'stockQuantity': stockQuantity,
      'isActive': isActive,
      'attributes': attributes,
    };
  }

  /// Parses a Firestore product document while tolerating older catalog fields.
  factory Product.fromDoc(DocumentSnapshot doc) {
    final rawData = doc.data();
    final data = rawData is Map<String, dynamic>
        ? rawData
        : rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : <String, dynamic>{};
    final ratingValue = data['rating'];
    final rating = ratingValue is Map
        ? _asDouble(ratingValue['rate'], 4.5)
        : _asDouble(ratingValue, 4.5);

    return Product(
      id: doc.id,
      name: _asString(data['name'] ?? data['title'], 'Unknown Product'),
      nameAr: _asString(data['nameAr']),
      categoryId: _asString(data['categoryId'] ?? data['category'], 'others'),
      categoryAr: _asString(data['categoryAr']),
      price: _asDouble(data['price'], 0),
      oldPrice: data['oldPrice'] == null
          ? null
          : _asDouble(data['oldPrice'], 0),
      discountPercentage: data['discountPercentage'] == null
          ? null
          : _asInt(data['discountPercentage']),
      timeLeft: data['timeLeft']?.toString(),
      imageUrl: _asString(data['imageUrl'] ?? data['image']),
      description: _asString(data['description']),
      descriptionAr: _asString(data['descriptionAr']),
      rating: rating,
      storeId: _asString(data['storeId'], 'independent-store'),
      storeName: _asString(data['storeName'], 'Independent Store'),
      storeNameAr: _asString(data['storeNameAr'], 'متجر مستقل'),
      sellerId: _asString(data['sellerId'], 'independent-seller'),
      sellerName: _asString(data['sellerName'], 'Independent seller'),
      sellerNameAr: _asString(data['sellerNameAr'], 'بائع مستقل'),
      stockQuantity: _asInt(data['stockQuantity'], 12),
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
      attributes: _asStringMap(data['attributes']),
    );
  }

  static String _asString(Object? value, [String fallback = '']) =>
      value == null ? fallback : value.toString();

  static double _asDouble(Object? value, [double fallback = 0]) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? fallback;

  static int _asInt(Object? value, [int fallback = 0]) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? fallback;

  static Map<String, String> _asStringMap(Object? value) {
    if (value is! Map) return const {};
    return value.map(
      (key, entryValue) => MapEntry(key.toString(), entryValue?.toString() ?? ''),
    );
  }
}
