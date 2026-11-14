import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../localization/marketplace_copy.dart';
import '../../models/marketplace_models.dart';
import '../../models/product.dart';
import '../../providers/marketplace_provider.dart';
import '../../widgets/marketplace_widgets.dart';
import 'marketplace_product_detail_screen.dart';

class MarketplaceHomeScreen extends StatelessWidget {
  const MarketplaceHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        final products = market.visibleProducts;
        final stores = market.activeStores;
        final isFiltered = market.query.isNotEmpty ||
            market.selectedCategoryId != null ||
            market.selectedStoreId != null ||
            market.onlyAvailable ||
            market.minimumPrice > 0 ||
            market.maximumPrice < 2000;
        final selectedStore = market.selectedStoreId == null
            ? null
            : market.storeById(market.selectedStoreId!);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MarketplaceHero(storeCount: stores.length, productCount: market.activeProducts.length),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: ValueKey(market.query.isEmpty ? 'market-search-empty' : 'market-search-filled'),
                      onChanged: market.setQuery,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: marketText(context, 'Search products, stores and makers', 'ابحث عن المنتجات والمتاجر والبائعين'),
                        prefixIcon: const Icon(Icons.search_rounded, color: marketplaceTeal),
                        suffixIcon: market.query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: marketText(context, 'Clear search', 'مسح البحث'),
                                onPressed: () => market.setQuery(''),
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        builder: (_) => _MarketplaceFilterSheet(
                          initialMin: market.minimumPrice,
                          initialMax: market.maximumPrice,
                          initialOnlyAvailable: market.onlyAvailable,
                          initialSort: market.sort,
                          initialStoreId: market.selectedStoreId,
                          stores: market.activeStores,
                        ),
                      ),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          border: Border.all(color: marketplaceLine),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.tune_rounded, color: marketplaceInk),
                            if (isFiltered)
                              Positioned(
                                top: 9,
                                right: 9,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: marketplaceCoral, shape: BoxShape.circle),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionHeading(
                title: marketText(context, 'Shop by category', 'تسوق حسب الفئة'),
                subtitle: marketText(context, 'Find the right corner of the marketplace', 'اكتشف ما يناسبك في السوق'),
              ),
              const SizedBox(height: 11),
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: market.categories.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final selected = market.selectedCategoryId == null;
                      return _CategoryChip(
                        label: marketText(context, 'All', 'الكل'),
                        icon: Icons.apps_rounded,
                        selected: selected,
                        onTap: () => market.setCategory(null),
                      );
                    }
                    final category = market.categories[index - 1];
                    return _CategoryChip(
                      label: categoryTitle(context, category),
                      iconText: category.icon,
                      selected: market.selectedCategoryId == category.id,
                      onTap: () => market.setCategory(
                        market.selectedCategoryId == category.id ? null : category.id,
                      ),
                    );
                  },
                ),
              ),
              if (selectedStore != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: InputChip(
                    avatar: const Icon(Icons.storefront_outlined, size: 18),
                    label: Text(
                      '${marketText(context, 'Store', 'المتجر')}: ${storeTitle(context, selectedStore)}',
                    ),
                    onDeleted: () => market.setStoreFilter(null),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              _SectionHeading(
                title: marketText(context, 'Independent stores', 'متاجر مستقلة'),
                subtitle: marketText(context, 'Meet the people behind the products', 'تعرّف على أصحاب المتاجر والمنتجات'),
                action: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const StoreDirectoryScreen()),
                  ),
                  child: Text(marketText(context, 'All stores', 'كل المتاجر')),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 126,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: stores.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final store = stores[index];
                    return SizedBox(
                      width: 276,
                      child: MarketplaceStoreCard(
                        store: store,
                        productCount: market.productsForStore(store.id).length,
                        compact: true,
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StoreDetailScreen(storeId: store.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              _SectionHeading(
                title: isFiltered
                    ? marketText(context, 'Marketplace results', 'نتائج السوق')
                    : marketText(context, 'Discover something new', 'اكتشف شيئاً جديداً'),
                subtitle: marketText(
                  context,
                  '${products.length} products from independent sellers',
                  '${products.length} منتجاً من بائعين مستقلين',
                ),
                action: market.sort == MarketplaceSort.featured
                    ? null
                    : TextButton.icon(
                        onPressed: market.clearFilters,
                        icon: const Icon(Icons.restart_alt_rounded, size: 17),
                        label: Text(marketText(context, 'Reset', 'إعادة ضبط')),
                      ),
              ),
              const SizedBox(height: 12),
              if (products.isEmpty)
                MarketplaceEmptyState(
                  icon: Icons.search_off_rounded,
                  title: marketText(context, 'No matching products', 'لا توجد منتجات مطابقة'),
                  description: marketText(context, 'Try changing your search or filters.', 'جرّب تغيير كلمات البحث أو عوامل التصفية.'),
                  action: OutlinedButton(
                    onPressed: market.clearFilters,
                    child: Text(marketText(context, 'Clear filters', 'مسح عوامل التصفية')),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final count = constraints.maxWidth >= 1120
                        ? 4
                        : constraints.maxWidth >= 760
                            ? 3
                            : constraints.maxWidth >= 390
                                ? 2
                                : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: count,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: count == 1 ? 1.05 : count == 2 ? 0.65 : 0.9,
                      ),
                      itemBuilder: (context, index) => MarketplaceProductCard(
                        product: products[index],
                        onOpen: () => _openProduct(context, products[index]),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _openProduct(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketplaceProductDetailScreen(productId: product.id),
      ),
    );
  }
}

class StoreDirectoryScreen extends StatelessWidget {
  const StoreDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        final stores = market.matchingStores;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarketplacePageTitle(
                title: marketText(context, 'Meet the stores', 'تعرّف على المتاجر'),
                subtitle: marketText(
                  context,
                  'Every shop is independently owned. Browse their stories, then shop across stores in one place.',
                  'كل متجر مستقل بذاته. تعرّف على أصحابه وتسوق من متاجر مختلفة في مكان واحد.',
                ),
              ),
              TextField(
                onChanged: market.setQuery,
                decoration: InputDecoration(
                  hintText: marketText(context, 'Search stores and sellers', 'ابحث عن المتاجر والبائعين'),
                  prefixIcon: const Icon(Icons.search_rounded, color: marketplaceTeal),
                ),
              ),
              const SizedBox(height: 18),
              if (stores.isEmpty)
                MarketplaceEmptyState(
                  icon: Icons.store_mall_directory_outlined,
                  title: marketText(context, 'No stores found', 'لم يتم العثور على متاجر'),
                  description: marketText(context, 'Try another store name or search term.', 'جرّب اسماً أو كلمة بحث أخرى.'),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final count = constraints.maxWidth >= 1050
                        ? 3
                        : constraints.maxWidth >= 650
                            ? 2
                            : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: stores.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: count,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: 205,
                      ),
                      itemBuilder: (context, index) {
                        final store = stores[index];
                        return MarketplaceStoreCard(
                          store: store,
                          productCount: market.productsForStore(store.id).length,
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StoreDetailScreen(storeId: store.id),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class StoreDetailScreen extends StatelessWidget {
  final String storeId;

  const StoreDetailScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        final store = market.storeById(storeId);
        if (store == null) {
          return Scaffold(
            appBar: AppBar(),
            body: MarketplaceEmptyState(
              icon: Icons.storefront_outlined,
              title: marketText(context, 'Store not found', 'المتجر غير موجود'),
              description: marketText(context, 'This store may no longer be available.', 'قد لا يكون هذا المتجر متاحاً الآن.'),
            ),
          );
        }
        final products = market.productsForStore(store.id);
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        return Scaffold(
          backgroundColor: marketplaceCanvas,
          appBar: AppBar(
            title: Text(storeTitle(context, store)),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: StatusPill(
                  label: storeStatusTitle(context, store.status),
                  color: store.isOpen ? marketplaceTeal : marketplaceCoral,
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF146C65), Color(0xFF244B5B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          StoreAvatar(store: store, size: 76),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        storeTitle(context, store),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    if (store.isVerified) ...[
                                      const SizedBox(width: 5),
                                      const Icon(Icons.verified_rounded, color: Color(0xFF76D6C2), size: 20),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isArabic && store.descriptionAr.isNotEmpty ? store.descriptionAr : store.description,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 6,
                                  children: [
                                    _HeroMeta(icon: Icons.location_on_outlined, label: store.city),
                                    _HeroMeta(icon: Icons.star_rounded, label: '${store.rating.toStringAsFixed(1)} · ${store.reviewCount} ${marketText(context, 'reviews', 'تقييم')}'),
                                    _HeroMeta(icon: Icons.inventory_2_outlined, label: '${products.length} ${marketText(context, 'products', 'منتج')}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeading(
                      title: marketText(context, 'From this store', 'منتجات هذا المتجر'),
                      subtitle: marketText(context, 'Each listing is managed by this independent seller.', 'يدير هذا البائع المستقل جميع منتجات المتجر.'),
                    ),
                    const SizedBox(height: 12),
                    if (products.isEmpty)
                      MarketplaceEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: marketText(context, 'No active products yet', 'لا توجد منتجات متاحة حالياً'),
                        description: marketText(context, 'Check back soon for new items from this store.', 'عد لاحقاً للاطلاع على المنتجات الجديدة.'),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final count = constraints.maxWidth >= 1000
                              ? 4
                              : constraints.maxWidth >= 700
                                  ? 3
                                  : constraints.maxWidth >= 390
                                      ? 2
                                      : 1;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: products.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: count,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: count == 1 ? 1.05 : count == 2 ? 0.65 : 0.9,
                            ),
                            itemBuilder: (context, index) => MarketplaceProductCard(
                              product: products[index],
                              onOpen: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => MarketplaceProductDetailScreen(productId: products[index].id),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MarketplaceCompareScreen extends StatelessWidget {
  final VoidCallback onContinueShopping;

  const MarketplaceCompareScreen({super.key, required this.onContinueShopping});

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        final products = market.comparedProducts;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarketplacePageTitle(
                title: marketText(context, 'Compare products', 'مقارنة المنتجات'),
                subtitle: marketText(context, 'Compare up to four products from the same category, including their stores and stock.', 'قارن حتى أربعة منتجات من الفئة نفسها، مع المتجر والمخزون.'),
                trailing: products.isEmpty
                    ? null
                    : TextButton(
                        onPressed: market.clearComparison,
                        child: Text(marketText(context, 'Clear', 'مسح')),
                      ),
              ),
              if (products.isEmpty)
                MarketplaceEmptyState(
                  icon: Icons.compare_arrows_rounded,
                  title: marketText(context, 'Your comparison is empty', 'قائمة المقارنة فارغة'),
                  description: marketText(context, 'Use the compare button on a product card to start comparing options from different stores.', 'استخدم زر المقارنة على بطاقة المنتج لمقارنة خيارات من متاجر مختلفة.'),
                  action: FilledButton(
                    onPressed: onContinueShopping,
                    child: Text(marketText(context, 'Browse the marketplace', 'تصفح السوق')),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: products.map((product) {
                      final store = market.storeById(product.storeId);
                      final available = product.isAvailable && (store?.isOpen ?? false);
                      return Container(
                        width: 258,
                        margin: const EdgeInsetsDirectional.only(end: 13),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: marketplaceLine),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: MarketplaceImage(
                                    imageUrl: product.imageUrl,
                                    width: 226,
                                    height: 148,
                                    fallbackIcon: Icons.inventory_2_outlined,
                                  ),
                                ),
                                PositionedDirectional(
                                  top: 7,
                                  end: 7,
                                  child: IconButton.filledTonal(
                                    tooltip: marketText(context, 'Remove', 'إزالة'),
                                    onPressed: () => market.removeFromComparison(product.id),
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 13),
                            Text(categoryTitleById(context, product.categoryId), style: const TextStyle(color: marketplaceTeal, fontSize: 10, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 5),
                            Text(productTitle(context, product), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: marketplaceInk, fontSize: 15, height: 1.2, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            _CompareRow(label: marketText(context, 'Price', 'السعر'), value: money(product.price), emphasize: true),
                            _CompareRow(label: marketText(context, 'Store', 'المتجر'), value: store == null ? product.storeName : storeTitle(context, store)),
                            _CompareRow(
                              label: marketText(context, 'Availability', 'التوفر'),
                              value: available
                                  ? marketText(context, '${product.stockQuantity} in stock', 'متوفر (${product.stockQuantity})')
                                  : marketText(context, 'Out of stock or store closed', 'نفد المخزون أو المتجر مغلق'),
                            ),
                            _CompareRow(label: marketText(context, 'Rating', 'التقييم'), value: '★ ${product.rating.toStringAsFixed(1)}'),
                            const Divider(height: 18),
                            ...product.attributes.entries.map(
                              (entry) => _CompareRow(
                                label: _attributeLabel(context, entry.key),
                                value: entry.value,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.tonalIcon(
                                onPressed: available
                                    ? () => _notifyCart(context, market.addToCart(product))
                                    : null,
                                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                                label: Text(marketText(context, 'Add to cart', 'أضف للسلة')),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 16),
              if (products.isNotEmpty)
                Text(
                  marketText(context, 'Tip: unavailable products stay visible here so you can compare their current stock status.', 'ملاحظة: تبقى المنتجات غير المتاحة ظاهرة لتتمكن من مقارنة حالة المخزون.'),
                  style: const TextStyle(color: marketplaceMuted, fontSize: 12, height: 1.4),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _attributeLabel(BuildContext context, String name) {
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
    return isArabic(context) ? translations[name] ?? name : name;
  }

  static void _notifyCart(BuildContext context, CartMutationResult result) {
    final message = result == CartMutationResult.success
        ? marketText(context, 'Added to your multi-store cart.', 'أضيف المنتج إلى سلتك متعددة المتاجر.')
        : marketText(context, 'This item is no longer available in that quantity.', 'الكمية المطلوبة لم تعد متاحة.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }
}

class _MarketplaceHero extends StatelessWidget {
  final int storeCount;
  final int productCount;

  const _MarketplaceHero({required this.storeCount, required this.productCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF176E68), Color(0xFF1F5961), Color(0xFF24485D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -6,
            top: -20,
            child: Icon(Icons.waves_rounded, size: 160, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
                child: Text(
                  marketText(context, 'ONE MARKET · MANY INDEPENDENT SHOPS', 'سوق واحد · متاجر مستقلة متعددة'),
                  style: const TextStyle(color: Colors.white, fontSize: 9, letterSpacing: 0.9, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  marketText(context, 'Find your next favorite store.', 'اعثر على متجرك المفضل التالي.'),
                  style: const TextStyle(color: Colors.white, fontSize: 26, height: 1.12, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Text(
                  marketText(
                    context,
                    'Explore independent sellers, compare products across shops, and keep every store connected through one simple checkout.',
                    'اكتشف البائعين المستقلين، وقارن المنتجات بين المتاجر، وأكمل مشترياتك عبر سلة موحدة.',
                  ),
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.55),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _HeroMeta(icon: Icons.storefront_rounded, label: '$storeCount ${marketText(context, 'independent stores', 'متاجر مستقلة')}'),
                  _HeroMeta(icon: Icons.inventory_2_outlined, label: '$productCount ${marketText(context, 'products', 'منتج')}'),
                  _HeroMeta(icon: Icons.verified_user_outlined, label: marketText(context, 'Verified sellers', 'بائعون معتمدون')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF99E4D1)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const _SectionHeading({required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: marketplaceInk, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: marketplaceMuted, fontSize: 11)),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? iconText;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    this.icon,
    this.iconText,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? marketplaceTeal : marketplaceInk;
    return Material(
      color: selected ? const Color(0xFFE4F1EF) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(border: Border.all(color: selected ? marketplaceTeal.withValues(alpha: 0.25) : marketplaceLine), borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconText != null) Text(iconText!, style: const TextStyle(fontSize: 14)) else if (icon != null) Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _CompareRow({required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: marketplaceMuted, fontSize: 10))),
          const SizedBox(width: 6),
          Expanded(child: Text(value, style: TextStyle(color: emphasize ? marketplaceTeal : marketplaceInk, fontSize: emphasize ? 13 : 10, fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600))),
        ],
      ),
    );
  }
}

class _MarketplaceFilterSheet extends StatefulWidget {
  final double initialMin;
  final double initialMax;
  final bool initialOnlyAvailable;
  final MarketplaceSort initialSort;
  final String? initialStoreId;
  final List<MarketplaceStore> stores;

  const _MarketplaceFilterSheet({
    required this.initialMin,
    required this.initialMax,
    required this.initialOnlyAvailable,
    required this.initialSort,
    required this.initialStoreId,
    required this.stores,
  });

  @override
  State<_MarketplaceFilterSheet> createState() => _MarketplaceFilterSheetState();
}

class _MarketplaceFilterSheetState extends State<_MarketplaceFilterSheet> {
  late RangeValues _priceRange;
  late bool _onlyAvailable;
  late MarketplaceSort _sort;
  late String _storeId;

  @override
  void initState() {
    super.initState();
    _priceRange = RangeValues(
      widget.initialMin.clamp(0, 2000).toDouble(),
      widget.initialMax.clamp(0, 2000).toDouble(),
    );
    _onlyAvailable = widget.initialOnlyAvailable;
    _sort = widget.initialSort;
    _storeId = widget.initialStoreId ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 20, 22, 18 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(marketText(context, 'Filter the marketplace', 'تصفية السوق'), style: const TextStyle(color: marketplaceInk, fontSize: 19, fontWeight: FontWeight.w800))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 8),
              Text(marketText(context, 'Price range', 'نطاق السعر'), style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w700)),
              RangeSlider(
                values: _priceRange,
                min: 0,
                max: 2000,
                divisions: 40,
                labels: RangeLabels(money(_priceRange.start), money(_priceRange.end)),
                onChanged: (value) => setState(() => _priceRange = value),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(money(_priceRange.start), style: const TextStyle(color: marketplaceMuted, fontSize: 12)), Text(money(_priceRange.end), style: const TextStyle(color: marketplaceMuted, fontSize: 12))],
              ),
              const SizedBox(height: 13),
              DropdownButtonFormField<String>(
                value: _storeId,
                decoration: InputDecoration(labelText: marketText(context, 'Store', 'المتجر')),
                items: [
                  DropdownMenuItem(value: '', child: Text(marketText(context, 'All stores', 'كل المتاجر'))),
                  ...widget.stores.map((store) => DropdownMenuItem(value: store.id, child: Text(storeTitle(context, store), overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (value) => setState(() => _storeId = value ?? ''),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<MarketplaceSort>(
                value: _sort,
                decoration: InputDecoration(labelText: marketText(context, 'Sort results', 'ترتيب النتائج')),
                items: MarketplaceSort.values.map((sort) => DropdownMenuItem(value: sort, child: Text(_sortLabel(context, sort)))).toList(),
                onChanged: (value) => setState(() => _sort = value ?? MarketplaceSort.featured),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _onlyAvailable,
                activeColor: marketplaceTeal,
                title: Text(marketText(context, 'In-stock products only', 'المنتجات المتوفرة فقط'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                onChanged: (value) => setState(() => _onlyAvailable = value),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      context.read<MarketplaceProvider>().clearFilters();
                      Navigator.pop(context);
                    },
                    child: Text(marketText(context, 'Reset all', 'إعادة ضبط الكل')),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final market = context.read<MarketplaceProvider>();
                      market.setPriceRange(_priceRange.start, _priceRange.end);
                      market.setAvailabilityFilter(_onlyAvailable);
                      market.setStoreFilter(_storeId.isEmpty ? null : _storeId);
                      market.setSort(_sort);
                      Navigator.pop(context);
                    },
                    child: Text(marketText(context, 'Show results', 'عرض النتائج')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sortLabel(BuildContext context, MarketplaceSort sort) {
    switch (sort) {
      case MarketplaceSort.featured:
        return marketText(context, 'Recommended', 'الموصى بها');
      case MarketplaceSort.priceLowToHigh:
        return marketText(context, 'Price: low to high', 'السعر: من الأقل للأعلى');
      case MarketplaceSort.priceHighToLow:
        return marketText(context, 'Price: high to low', 'السعر: من الأعلى للأقل');
      case MarketplaceSort.highestRated:
        return marketText(context, 'Highest rated', 'الأعلى تقييماً');
    }
  }
}
