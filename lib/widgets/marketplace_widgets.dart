import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/marketplace_copy.dart';
import '../models/marketplace_models.dart';
import '../models/product.dart';
import '../providers/marketplace_provider.dart';
import '../theme/marketplace_palette.dart';

export '../theme/marketplace_palette.dart';

class MarketplaceImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;
  final BorderRadius? borderRadius;

  const MarketplaceImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.storefront_rounded,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      color: const Color(0xFFE5F1EF),
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: marketplaceTeal.withValues(alpha: 0.7), size: 34),
    );

    if (imageUrl.isEmpty) return _clip(fallback);
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            color: const Color(0xFFEFF4F3),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: marketplaceTeal),
            ),
          );
        },
      ),
    );
  }

  Widget _clip(Widget child) => ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: child,
      );
}

class StoreAvatar extends StatelessWidget {
  final MarketplaceStore store;
  final double size;

  const StoreAvatar({super.key, required this.store, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.34),
      child: SizedBox(
        width: size,
        height: size,
        child: store.logoUrl.isNotEmpty
            ? MarketplaceImage(
                imageUrl: store.logoUrl,
                width: size,
                height: size,
                fallbackIcon: Icons.storefront_rounded,
              )
            : Container(
                color: const Color(0xFFDDEFEA),
                alignment: Alignment.center,
                child: Text(
                  store.name.isNotEmpty ? store.name[0] : 'S',
                  style: TextStyle(
                    color: marketplaceTeal,
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }
}

class MarketplaceProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onOpen;

  const MarketplaceProductCard({
    super.key,
    required this.product,
    required this.onOpen,
  });

  void _notifyCompare(BuildContext context, CompareMutationResult result) {
    final message = switch (result) {
      CompareMutationResult.added => marketText(context, 'Added to compare', 'أضيف للمقارنة'),
      CompareMutationResult.removed => marketText(context, 'Removed from compare', 'أزيل من المقارنة'),
      CompareMutationResult.full => marketText(context, 'Compare up to four products.', 'يمكن مقارنة أربعة منتجات كحد أقصى.'),
      CompareMutationResult.differentCategory => marketText(context, 'Choose products from the same category.', 'اختر منتجات من الفئة نفسها.'),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  void _addToCart(BuildContext context, CartMutationResult result) {
    final message = switch (result) {
      CartMutationResult.success => marketText(context, 'Added to your multi-store cart', 'أضيف المنتج إلى سلتك متعددة المتاجر'),
      CartMutationResult.unavailable => marketText(context, 'This item is currently unavailable.', 'هذا المنتج غير متاح حالياً.'),
      CartMutationResult.stockLimitReached => marketText(context, 'You have reached the available stock.', 'وصلت إلى الكمية المتاحة في المخزون.'),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.select<MarketplaceProvider, MarketplaceStore?>(
      (market) => market.storeById(product.storeId),
    );
    final available = product.isAvailable && (store?.isOpen ?? false);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: marketplaceLine),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 11,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MarketplaceImage(
                    imageUrl: product.imageUrl,
                    fallbackIcon: Icons.inventory_2_outlined,
                  ),
                  Positioned(
                    top: 9,
                    left: 9,
                    child: _roundAction(
                      icon: context.select<MarketplaceProvider, bool>(
                        (market) => market.isFavorite(product),
                      )
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: context.select<MarketplaceProvider, bool>(
                        (market) => market.isFavorite(product),
                      )
                          ? marketplaceCoral
                          : marketplaceInk,
                      tooltip: marketText(context, 'Save product', 'حفظ المنتج'),
                      onPressed: () => context.read<MarketplaceProvider>().toggleFavorite(product),
                    ),
                  ),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: _roundAction(
                      icon: context.select<MarketplaceProvider, bool>(
                        (market) => market.isCompared(product),
                      )
                          ? Icons.check_rounded
                          : Icons.compare_arrows_rounded,
                      color: marketplaceTeal,
                      tooltip: marketText(context, 'Compare', 'قارن'),
                      onPressed: () => _notifyCompare(
                        context,
                        context.read<MarketplaceProvider>().toggleComparison(product),
                      ),
                    ),
                  ),
                  if (!available)
                    Positioned(
                      bottom: 9,
                      left: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: marketplaceInk.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          marketText(context, 'Out of stock', 'نفد المخزون'),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  if (product.discountPercentage != null)
                    Positioned(
                      top: 52,
                      left: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: marketplaceCoral,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '-${product.discountPercentage}%',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (store != null) StoreAvatar(store: store, size: 19),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            store == null ? product.storeName : storeTitle(context, store),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: marketplaceMuted, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (store?.isVerified ?? false)
                          const Icon(Icons.verified_rounded, color: marketplaceTeal, size: 14),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      productTitle(context, product),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: marketplaceInk, fontSize: 13, height: 1.15, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFE3A72F), size: 15),
                        const SizedBox(width: 2),
                        Text(product.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text(
                          money(product.price),
                          style: const TextStyle(color: marketplaceInk, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: FilledButton.tonalIcon(
                        onPressed: available
                            ? () => _addToCart(
                                  context,
                                  context.read<MarketplaceProvider>().addToCart(product),
                                )
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEAF4F2),
                          foregroundColor: marketplaceTeal,
                          disabledForegroundColor: marketplaceMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 15),
                        label: Text(
                          marketText(context, 'Add to cart', 'أضف للسلة'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        icon: Icon(icon, color: color),
      ),
    );
  }
}

class MarketplaceStoreCard extends StatelessWidget {
  final MarketplaceStore store;
  final int productCount;
  final VoidCallback onOpen;
  final bool compact;

  const MarketplaceStoreCard({
    super.key,
    required this.store,
    required this.productCount,
    required this.onOpen,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: marketplaceLine),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: compact
            ? _compactContent(context)
            : _wideContent(context),
      ),
    );
  }

  Widget _compactContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          StoreAvatar(store: store, size: 52),
          const SizedBox(width: 12),
          Expanded(child: _storeInfo(context)),
          const Icon(Icons.chevron_right_rounded, color: marketplaceMuted),
        ],
      ),
    );
  }

  Widget _wideContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoreAvatar(store: store, size: 54),
              const Spacer(),
              StatusPill(
                label: storeStatusTitle(context, store.status),
                color: store.isOpen ? marketplaceTeal : marketplaceCoral,
              ),
            ],
          ),
          const SizedBox(height: 13),
          _storeInfo(context),
          const SizedBox(height: 11),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFE3A72F), size: 16),
              const SizedBox(width: 3),
              Text(store.rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(width: 8),
              Text('· $productCount ${marketText(context, 'products', 'منتج')}', style: const TextStyle(color: marketplaceMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _storeInfo(BuildContext context) {
    final localizedDescription = isArabic(context) && store.descriptionAr.isNotEmpty
        ? store.descriptionAr
        : store.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                storeTitle(context, store),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: marketplaceInk, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            if (store.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified_rounded, color: marketplaceTeal, size: 16),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Text(
          localizedDescription,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: marketplaceMuted, fontSize: 11, height: 1.35),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 13, color: marketplaceMuted),
            const SizedBox(width: 3),
            Text(store.city, style: const TextStyle(color: marketplaceMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

class MarketplacePageTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const MarketplacePageTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: marketplaceInk, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(subtitle, style: const TextStyle(color: marketplaceMuted, fontSize: 13, height: 1.35)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, this.color = marketplaceTeal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class MarketplaceMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? note;

  const MarketplaceMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = marketplaceTeal,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: marketplaceLine),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 19, color: color),
              ),
              const Spacer(),
              if (note != null) Text(note!, style: const TextStyle(color: marketplaceMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(color: marketplaceInk, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: marketplaceMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class MarketplaceEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  const MarketplaceEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(color: Color(0xFFEAF4F2), shape: BoxShape.circle),
              child: Icon(icon, color: marketplaceTeal, size: 34),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 7),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(color: marketplaceMuted, fontSize: 13, height: 1.45)),
            if (action != null) ...[const SizedBox(height: 17), action!],
          ],
        ),
      ),
    );
  }
}
