import 'product.dart';

enum MarketplaceRole { customer, seller, admin }

enum MarketplaceSort { featured, priceLowToHigh, priceHighToLow, highestRated }

enum StoreStatus { active, paused, suspended }

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

  MarketplaceStore copyWith({
    String? name,
    String? nameAr,
    String? description,
    String? descriptionAr,
    String? city,
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
      logoUrl: logoUrl,
      coverUrl: coverUrl,
      rating: rating,
      reviewCount: reviewCount,
      isVerified: isVerified,
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
