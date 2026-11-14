import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/marketplace_models.dart';
import '../models/product.dart';

/// The only client boundary for marketplace data. All sensitive mutations are
/// callable Cloud Functions; Firestore rules are read-only for marketplace data.
class FirebaseMarketplaceRepository {
  FirebaseMarketplaceRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  String newProductId() => firestore.collection('products').doc().id;

  Stream<List<MarketplaceStore>> watchPublicStores() => firestore
      .collection('stores')
      .where('status', isEqualTo: 'active')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => MarketplaceStore.fromJson(doc.id, doc.data()))
          .toList(growable: false));

  Stream<MarketplaceStore?> watchOwnedStore(String sellerId) => firestore
      .collection('stores')
      .doc('store-$sellerId')
      .snapshots()
      .map((doc) => doc.exists
          ? MarketplaceStore.fromJson(doc.id, doc.data()!)
          : null);

  Stream<List<MarketplaceStore>> watchAdminStores() => firestore
      .collection('stores')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => MarketplaceStore.fromJson(doc.id, doc.data()))
          .toList(growable: false));

  Stream<List<Product>> watchPublicProducts() => firestore
      .collection('products')
      .where('isActive', isEqualTo: true)
      .where('storeStatus', isEqualTo: 'active')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Product.fromDoc(doc))
          .toList(growable: false));

  Stream<List<Product>> watchOwnProducts(String sellerId) => firestore
      .collection('products')
      .where('sellerId', isEqualTo: sellerId)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Product.fromDoc(doc))
          .toList(growable: false));

  Stream<List<Product>> watchAdminProducts() => firestore
      .collection('products')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Product.fromDoc(doc))
          .toList(growable: false));

  Stream<SellerApplication?> watchSellerApplication(String sellerId) =>
      firestore
          .collection('sellerApplications')
          .doc(sellerId)
          .snapshots()
          .map((doc) => doc.exists
              ? SellerApplication.fromJson(doc.id, doc.data()!)
              : null);

  Stream<List<SellerApplication>> watchAdminApplications() => firestore
      .collection('sellerApplications')
      .orderBy('submittedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => SellerApplication.fromJson(doc.id, doc.data()))
          .toList(growable: false));

  Stream<List<MarketplaceOrder>> watchCustomerOrders(String customerId) =>
      firestore
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(_ordersFromSnapshot);

  Stream<List<MarketplaceOrder>> watchAdminOrders() => firestore
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_ordersFromSnapshot);

  Stream<List<StoreOrder>> watchSellerOrders(String sellerId) => firestore
      .collection('sellerOrders')
      .where('sellerId', isEqualTo: sellerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            final child = data['storeOrder'];
            return StoreOrder.fromJson(
              doc.id,
              child is Map
                  ? Map<String, dynamic>.from(child)
                  : <String, dynamic>{},
            );
          }).toList(growable: false));

  Stream<List<MarketplaceAuditEvent>> watchAdminAuditEvents() => firestore
      .collection('auditEvents')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return MarketplaceAuditEvent(
              createdAt: _asDate(data['createdAt']),
              actor: _asString(data['actor']),
              action: _asString(data['action']),
              target: _asString(data['target']),
            );
          }).toList(growable: false));

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    final result = await functions.httpsCallable(name).call(data);
    if (result.data is Map) {
      return Map<String, dynamic>.from(result.data as Map);
    }
    return <String, dynamic>{};
  }

  Future<MarketplaceOrder> placeSandboxOrder({
    required String requestId,
    required Map<String, int> cart,
    required CheckoutDetails details,
  }) async {
    final result = await call('createSandboxOrder', {
      'requestId': requestId,
      'items': cart.entries
          .map((entry) => {
                'productId': entry.key,
                'quantity': entry.value,
              })
          .toList(growable: false),
      'customerName': details.customerName.trim(),
      'customerPhone': details.customerPhone.trim(),
      'deliveryAddress': details.deliveryAddress.trim(),
    });
    final orderId = result['orderId']?.toString() ?? '';
    if (orderId.isEmpty) {
      throw StateError('The order service returned no order identifier.');
    }
    final snapshot = await firestore.collection('orders').doc(orderId).get();
    if (!snapshot.exists) {
      throw StateError('The order was accepted but could not be loaded.');
    }
    return MarketplaceOrder.fromJson(orderId, snapshot.data()!);
  }

  static List<MarketplaceOrder> _ordersFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => snapshot.docs.map((doc) {
        final data = doc.data();
        final rawChildren = data['storeOrders'];
        final children = rawChildren is List
            ? rawChildren.whereType<Map>().map((value) {
                final item = Map<String, dynamic>.from(value);
                return StoreOrder.fromJson(
                  _asString(item['id']),
                  item,
                );
              }).toList(growable: false)
            : const <StoreOrder>[];
        return MarketplaceOrder.fromJson(
          doc.id,
          data,
          storeOrders: children,
        );
      }).toList(growable: false);

  static DateTime _asDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  static String _asString(Object? value) => value?.toString() ?? '';
}
