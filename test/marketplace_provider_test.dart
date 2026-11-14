import 'package:flutter_test/flutter_test.dart';
import 'package:shop_wave/models/marketplace_models.dart';
import 'package:shop_wave/providers/marketplace_provider.dart';

void main() {
  group('MarketplaceProvider multi-vendor flows', () {
    test('keeps store context and splits one cart into store sub-orders', () {
      final market = MarketplaceProvider();
      final iphone = market.productById('p-iphone-16-pro')!;
      final headphones = market.productById('p-sonic-headphones')!;
      final galaxy = market.productById('p-galaxy-s25')!;

      expect(market.addToCart(iphone), CartMutationResult.success);
      expect(market.addToCart(headphones), CartMutationResult.success);
      expect(market.addToCart(galaxy), CartMutationResult.success);
      expect(market.cartStoreCount, 2);

      final result = market.checkoutDemo(
        const CheckoutDetails(
          customerName: 'Test customer',
          customerPhone: '777000000',
          deliveryAddress: 'Aden, Yemen',
        ),
      );

      expect(result.isSuccess, isTrue);
      final order = result.order!;
      expect(order.paymentStatus, PaymentStatus.sandboxApproved);
      expect(order.storeOrders, hasLength(2));
      expect(order.storeOrders.map((item) => item.storeId).toSet(), hasLength(2));
      final novaOrder = order.storeOrders.firstWhere((item) => item.storeId == 'store-nova');
      expect(novaOrder.lines, hasLength(2));
      expect(novaOrder.lines.every((line) => line.storeId == 'store-nova'), isTrue);
      expect(market.cartItemCount, 0);
      expect(market.productById(iphone.id)!.stockQuantity, iphone.stockQuantity - 1);
    });

    test('allows comparison only within one category and caps the set at four', () {
      final market = MarketplaceProvider();
      final phones = [
        'p-iphone-16-pro',
        'p-galaxy-s25',
        'p-pixel-9',
        'p-oneplus-13',
        'p-xiaomi-14',
      ].map((id) => market.productById(id)!).toList();

      expect(market.toggleComparison(phones[0]), CompareMutationResult.added);
      expect(market.toggleComparison(market.productById('p-sonic-headphones')!), CompareMutationResult.differentCategory);
      expect(market.toggleComparison(phones[1]), CompareMutationResult.added);
      expect(market.toggleComparison(phones[2]), CompareMutationResult.added);
      expect(market.toggleComparison(phones[3]), CompareMutationResult.added);
      expect(market.toggleComparison(phones[4]), CompareMutationResult.full);
      expect(market.comparedProducts, hasLength(4));
    });

    test('searches store names and filters/sorts a unified marketplace catalog', () {
      final market = MarketplaceProvider();
      market.setQuery('Nova Tech');
      expect(market.visibleProducts, isNotEmpty);
      expect(market.visibleProducts.every((product) => product.storeId == 'store-nova'), isTrue);

      market.setQuery('');
      market.setCategory('smartphones');
      market.setAvailabilityFilter(true);
      market.setSort(MarketplaceSort.priceLowToHigh);
      final results = market.visibleProducts;
      expect(results.every((product) => product.categoryId == 'smartphones'), isTrue);
      expect(results.every((product) => product.isAvailable), isTrue);
      expect(results.first.id, 'p-xiaomi-14');
    });

    test('prevents buying unavailable products and exceeding stock', () {
      final market = MarketplaceProvider();
      final outOfStock = market.productById('p-pixel-9')!;
      final inStock = market.productById('p-oneplus-13')!;

      expect(market.addToCart(outOfStock), CartMutationResult.unavailable);
      for (var index = 0; index < inStock.stockQuantity; index++) {
        expect(market.addToCart(inStock), CartMutationResult.success);
      }
      expect(market.addToCart(inStock), CartMutationResult.stockLimitReached);
      expect(market.setCartQuantity(inStock.id, inStock.stockQuantity + 1), CartMutationResult.stockLimitReached);
    });

    test('seller updates are limited to that seller’s own catalog', () {
      final market = MarketplaceProvider()..setRole(MarketplaceRole.seller);
      final ownProduct = market.productById('p-iphone-16-pro')!;
      final otherSellerProduct = market.productById('p-galaxy-s25')!;

      expect(
        market.updateOwnProduct(
          productId: otherSellerProduct.id,
          price: 1,
          stockQuantity: 1,
          isActive: true,
        ),
        isFalse,
      );
      expect(
        market.updateOwnProduct(
          productId: ownProduct.id,
          price: 1049,
          stockQuantity: 4,
          isActive: true,
        ),
        isTrue,
      );
      expect(market.productById(ownProduct.id)!.price, 1049);
      expect(market.productById(otherSellerProduct.id)!.price, otherSellerProduct.price);
      expect(
        market.updateOwnProduct(
          productId: ownProduct.id,
          price: -1,
          stockQuantity: 4,
          isActive: true,
        ),
        isFalse,
      );
    });

    test('admin can review seller applications and actions are auditable', () {
      final market = MarketplaceProvider();
      final application = market.sellerApplications.first;
      final initialStoreCount = market.stores.length;

      expect(market.reviewSellerApplication(application.id, approve: true), isFalse);
      market.setRole(MarketplaceRole.admin);
      expect(market.reviewSellerApplication(application.id, approve: true), isTrue);
      expect(market.sellerApplications.first.status, SellerApplicationStatus.approved);
      expect(market.stores, hasLength(initialStoreCount + 1));
      expect(market.storeById('store-${application.id}'), isNotNull);
      expect(market.auditEvents, isNotEmpty);
    });

    test('customer can cancel only an eligible store sub-order and inventory is restored', () {
      final market = MarketplaceProvider();
      final iphone = market.productById('p-iphone-16-pro')!;
      final galaxy = market.productById('p-galaxy-s25')!;
      market.addToCart(iphone);
      market.addToCart(galaxy);
      final order = market.checkoutDemo(
        const CheckoutDetails(
          customerName: 'Test customer',
          customerPhone: '777000000',
          deliveryAddress: 'Aden, Yemen',
        ),
      ).order!;
      final novaOrder = order.storeOrders.firstWhere((item) => item.storeId == 'store-nova');
      final adenOrder = order.storeOrders.firstWhere((item) => item.storeId == 'store-aden-mobile');

      expect(market.cancelStoreOrder(order.id, novaOrder.id), isTrue);
      expect(market.orderById(order.id)!.storeOrders.firstWhere((item) => item.id == novaOrder.id).status, StoreOrderStatus.cancelled);
      expect(market.orderById(order.id)!.storeOrders.firstWhere((item) => item.id == adenOrder.id).status, StoreOrderStatus.awaitingSeller);
      expect(market.productById(iphone.id)!.stockQuantity, iphone.stockQuantity);

      market.setRole(MarketplaceRole.seller);
      expect(market.advanceSellerOrder(order.id, novaOrder.id), isFalse);
      expect(market.advanceSellerOrder(order.id, adenOrder.id), isFalse);
    });
  });
}
