import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../localization/marketplace_copy.dart';
import '../../models/marketplace_models.dart';
import '../../models/product.dart';
import '../../providers/marketplace_provider.dart';
import '../../widgets/marketplace_widgets.dart';

class MarketplaceProductDetailScreen extends StatelessWidget {
  final String productId;

  const MarketplaceProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        final product = market.productById(productId);
        if (product == null) {
          return Scaffold(
            appBar: AppBar(),
            body: MarketplaceEmptyState(
              icon: Icons.inventory_2_outlined,
              title: marketText(context, 'Product not found', 'المنتج غير موجود'),
              description: marketText(context, 'This listing may have been removed from the marketplace.', 'ربما أزيل هذا المنتج من السوق.'),
            ),
          );
        }
        final store = market.storeById(product.storeId);
        final available = product.isAvailable && (store?.isOpen ?? false);
        return Scaffold(
          backgroundColor: marketplaceCanvas,
          appBar: AppBar(
            title: Text(marketText(context, 'Product details', 'تفاصيل المنتج')),
            actions: [
              IconButton(
                tooltip: marketText(context, 'Compare', 'مقارنة'),
                onPressed: () => _toggleCompare(context, market, product),
                icon: Icon(
                  market.isCompared(product)
                      ? Icons.check_circle_rounded
                      : Icons.compare_arrows_rounded,
                  color: marketplaceTeal,
                ),
              ),
              IconButton(
                tooltip: marketText(context, 'Save product', 'حفظ المنتج'),
                onPressed: () => market.toggleFavorite(product),
                icon: Icon(
                  market.isFavorite(product)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: market.isFavorite(product) ? marketplaceCoral : marketplaceInk,
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final image = ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: wide ? 0.98 : 1.15,
                        child: MarketplaceImage(
                          imageUrl: product.imageUrl,
                          fallbackIcon: Icons.inventory_2_outlined,
                        ),
                      ),
                    );
                    final details = _ProductInformation(
                      product: product,
                      store: store,
                      available: available,
                      onAddToCart: () => _addToCart(context, market, product),
                    );
                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          image,
                          const SizedBox(height: 20),
                          details,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 11, child: image),
                        const SizedBox(width: 30),
                        Expanded(flex: 10, child: details),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleCompare(BuildContext context, MarketplaceProvider market, Product product) {
    final result = market.toggleComparison(product);
    final message = switch (result) {
      CompareMutationResult.added => marketText(context, 'Added to comparison.', 'أضيف للمقارنة.'),
      CompareMutationResult.removed => marketText(context, 'Removed from comparison.', 'أزيل من المقارنة.'),
      CompareMutationResult.full => marketText(context, 'Compare up to four products.', 'يمكن مقارنة أربعة منتجات كحد أقصى.'),
      CompareMutationResult.differentCategory => marketText(context, 'Only products in the same category can be compared.', 'يمكن مقارنة المنتجات من الفئة نفسها فقط.'),
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  void _addToCart(BuildContext context, MarketplaceProvider market, Product product) {
    final result = market.addToCart(product);
    final message = result == CartMutationResult.success
        ? marketText(context, 'Added to your cart.', 'أضيف إلى السلة.')
        : result == CartMutationResult.stockLimitReached
            ? marketText(context, 'You have reached the available stock.', 'وصلت إلى الكمية المتاحة.')
            : marketText(context, 'This product is currently unavailable.', 'هذا المنتج غير متاح حالياً.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }
}

class _ProductInformation extends StatelessWidget {
  final Product product;
  final MarketplaceStore? store;
  final bool available;
  final VoidCallback onAddToCart;

  const _ProductInformation({
    required this.product,
    required this.store,
    required this.available,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final description = productDescription(context, product);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusPill(
          label: categoryTitleById(context, product.categoryId),
          color: marketplaceTeal,
        ),
        const SizedBox(height: 12),
        Text(
          productTitle(context, product),
          style: const TextStyle(color: marketplaceInk, fontSize: 25, height: 1.15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFE3A72F), size: 19),
            const SizedBox(width: 4),
            Text(product.rating.toStringAsFixed(1), style: const TextStyle(color: marketplaceInk, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(width: 9),
            Text(marketText(context, 'Customer-rated listing', 'تقييم المنتج'), style: const TextStyle(color: marketplaceMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 17),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(product.price), style: const TextStyle(color: marketplaceTeal, fontSize: 26, fontWeight: FontWeight.w800)),
            if (product.oldPrice != null) ...[
              const SizedBox(width: 9),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(money(product.oldPrice!), style: const TextStyle(color: marketplaceMuted, fontSize: 14, decoration: TextDecoration.lineThrough)),
              ),
            ],
          ],
        ),
        if (product.discountPercentage != null) ...[
          const SizedBox(height: 5),
          Text('${marketText(context, 'Save', 'وفّر')} ${product.discountPercentage}% ${marketText(context, 'with this store listing', 'من سعر هذا المتجر')}', style: const TextStyle(color: marketplaceCoral, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 16),
        _StoreInformationCard(store: store, product: product),
        const SizedBox(height: 15),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: available ? const Color(0xFFEAF4F2) : const Color(0xFFFFF1EC),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Icon(available ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded, color: available ? marketplaceTeal : marketplaceCoral, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  available
                      ? marketText(context, '${product.stockQuantity} available from this store', 'متوفر لدى المتجر (${product.stockQuantity})')
                      : marketText(context, 'Currently unavailable. Add it to compare to check again later.', 'غير متاح حالياً. يمكنك إضافته للمقارنة ومراجعة توفره لاحقاً.'),
                  style: TextStyle(color: available ? marketplaceTeal : marketplaceCoral, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(marketText(context, 'About this product', 'عن المنتج'), style: const TextStyle(color: marketplaceInk, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Text(
          description.isEmpty ? marketText(context, 'Details supplied by the independent store.', 'التفاصيل مقدمة من المتجر المستقل.') : description,
          style: const TextStyle(color: marketplaceMuted, fontSize: 13, height: 1.55),
        ),
        if (product.attributes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(marketText(context, 'Product details', 'مواصفات المنتج'), style: const TextStyle(color: marketplaceInk, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Container(
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: product.attributes.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                child: Row(children: [Expanded(child: Text(_attributeLabel(context, entry.key), style: const TextStyle(color: marketplaceMuted, fontSize: 11))), Text(entry.value, style: const TextStyle(color: marketplaceInk, fontSize: 11, fontWeight: FontWeight.w700))]),
              )).toList(),
            ),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: available ? onAddToCart : null,
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: Text(marketText(context, 'Add to marketplace cart', 'أضف إلى سلة السوق')),
          ),
        ),
        const SizedBox(height: 8),
        Text(marketText(context, 'The store name and stock are shown before you add an item.', 'يظهر اسم المتجر والمخزون قبل إضافة المنتج.'), style: const TextStyle(color: marketplaceMuted, fontSize: 10), textAlign: TextAlign.center),
      ],
    );
  }

  String _attributeLabel(BuildContext context, String key) {
    if (!isArabic(context)) return key;
    const translations = <String, String>{
      'Storage': 'السعة',
      'Display': 'الشاشة',
      'Warranty': 'الضمان',
      'Battery': 'البطارية',
      'Connection': 'الاتصال',
      'Material': 'الخامة',
      'Finish': 'التشطيب',
      'Care': 'العناية',
      'Size': 'المقاس',
      'Fit': 'القصة',
      'Capacity': 'السعة',
      'Volume': 'الحجم',
      'Skin type': 'نوع البشرة',
      'Made in': 'بلد الصنع',
      'Fragrance': 'الرائحة',
      'Layout': 'التصميم',
      'Switches': 'المفاتيح',
      'Microphone': 'الميكروفون',
    };
    return translations[key] ?? key;
  }
}

class _StoreInformationCard extends StatelessWidget {
  final MarketplaceStore? store;
  final Product product;

  const _StoreInformationCard({required this.store, required this.product});

  @override
  Widget build(BuildContext context) {
    if (store == null) {
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(15)),
        child: Row(children: [const Icon(Icons.storefront_outlined, color: marketplaceTeal), const SizedBox(width: 9), Expanded(child: Text(product.displayStoreName(arabic: isArabic(context)), style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w700)))]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          StoreAvatar(store: store!, size: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Flexible(child: Text(storeTitle(context, store!), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: marketplaceInk, fontSize: 13, fontWeight: FontWeight.w800))), if (store!.isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, color: marketplaceTeal, size: 15)]]),
                const SizedBox(height: 4),
                Text(marketText(context, 'Sold and fulfilled by this independent store', 'يباع ويجهز من هذا المتجر المستقل'), style: const TextStyle(color: marketplaceMuted, fontSize: 10)),
                const SizedBox(height: 3),
                Text(
                  '${marketText(context, 'Seller', 'البائع')}: ${isArabic(context) && product.sellerNameAr.isNotEmpty ? product.sellerNameAr : product.sellerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: marketplaceMuted, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Row(children: [const Icon(Icons.star_rounded, size: 13, color: Color(0xFFE3A72F)), const SizedBox(width: 3), Text(store!.rating.toStringAsFixed(1), style: const TextStyle(color: marketplaceInk, fontSize: 10, fontWeight: FontWeight.w700)), const SizedBox(width: 8), Text('${store!.city} · ${storeStatusTitle(context, store!.status)}', style: const TextStyle(color: marketplaceMuted, fontSize: 10))]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
