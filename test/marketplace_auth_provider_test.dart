import 'package:flutter_test/flutter_test.dart';
import 'package:shop_wave/models/marketplace_models.dart';

void main() {
  group('Firebase marketplace identity models', () {
    test('profile serialization never contains credential material', () {
      const profile = MarketplaceUser(
        id: 'firebase-uid-01',
        username: 'amina.saleh',
        email: 'amina@example.com',
        displayName: 'Amina Saleh',
        role: MarketplaceRole.customer,
      );

      final serialized = profile.toJson();
      expect(serialized['id'], 'firebase-uid-01');
      expect(serialized['username'], 'amina.saleh');
      expect(serialized['role'], 'customer');
      expect(serialized.keys, isNot(contains('password')));
      expect(serialized.keys, isNot(contains('passwordHash')));
    });

    test('unrecognized client profile roles do not grant administrator access', () {
      final profile = MarketplaceUser.fromJson({
        'id': 'firebase-uid-02',
        'username': 'ordinary-user',
        'email': 'user@example.com',
        'displayName': 'Ordinary User',
        'role': 'administrator',
      });

      expect(profile.role, MarketplaceRole.customer);
    });

    test('pending store state and Firestore timestamp order maps parse safely', () {
      final store = MarketplaceStore.fromJson('store-seller-1', {
        'sellerId': 'seller-1',
        'name': 'Pending Store',
        'description': '',
        'categoryId': 'home',
        'status': 'pending',
      });
      final order = MarketplaceOrder.fromJson('order-1', {
        'customerId': 'customer-1',
        'createdAt': DateTime.utc(2026, 1, 1),
        'paymentStatus': 'sandboxApproved',
      });

      expect(store.status, StoreStatus.pending);
      expect(store.isOpen, isFalse);
      expect(order.paymentStatus, PaymentStatus.sandboxApproved);
      expect(order.storeOrders, isEmpty);
    });
  });
}
