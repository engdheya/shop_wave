import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../localization/marketplace_copy.dart';
import '../../models/marketplace_models.dart';
import '../../models/product.dart';
import '../../providers/marketplace_provider.dart';
import '../../widgets/marketplace_widgets.dart';

class SellerWorkspaceScreen extends StatelessWidget {
  final int section;
  final ValueChanged<int> onNavigate;

  const SellerWorkspaceScreen({
    super.key,
    required this.section,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case 0:
        return _SellerOverview(onNavigate: onNavigate);
      case 1:
        return const _SellerCatalogScreen();
      case 2:
        return const _SellerOrdersScreen();
      case 3:
        return const _SellerStoreProfileScreen();
      default:
        return _SellerOverview(onNavigate: onNavigate);
    }
  }
}

class _SellerOverview extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const _SellerOverview({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        final store = market.currentSellerStore;
        final products = market.currentSellerProducts;
        final orders = market.currentSellerOrders;
        final lowStock = products.where((product) => product.stockQuantity < 4).length;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarketplacePageTitle(
                    title: marketText(context, 'Seller workspace', 'لوحة البائع'),
                    subtitle: marketText(context, 'Manage your own store, catalog, stock and store orders.', 'أدر متجرك وكتالوجك ومخزونك وطلبات متجرك.'),
                    trailing: StatusPill(
                      label: store == null ? marketText(context, 'No store', 'لا يوجد متجر') : storeStatusTitle(context, store.status),
                      color: store?.isOpen ?? false ? marketplaceTeal : marketplaceCoral,
                    ),
                  ),
                  if (store != null)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF176E68), Color(0xFF24485D)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          StoreAvatar(store: store, size: 58),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(storeTitle(context, store), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(marketText(context, 'Only your store and its orders are shown here.', 'تظهر هنا بيانات متجرك وطلباته فقط.'), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => onNavigate(3),
                            icon: const Icon(Icons.edit_outlined, size: 17),
                            label: Text(marketText(context, 'Store profile', 'ملف المتجر')),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final count = constraints.maxWidth >= 760 ? 4 : 2;
                      return GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: count,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 126,
                        ),
                        children: [
                          MarketplaceMetricCard(label: marketText(context, 'My products', 'منتجاتي'), value: '${products.length}', icon: Icons.inventory_2_outlined),
                          MarketplaceMetricCard(label: marketText(context, 'Open store orders', 'طلبات المتجر المفتوحة'), value: '${orders.where((order) => order.status != StoreOrderStatus.completed && order.status != StoreOrderStatus.cancelled && order.status != StoreOrderStatus.declined).length}', icon: Icons.receipt_long_outlined, color: const Color(0xFF4379B8)),
                          MarketplaceMetricCard(label: marketText(context, 'Low stock', 'مخزون منخفض'), value: '$lowStock', icon: Icons.warning_amber_rounded, color: marketplaceCoral),
                          MarketplaceMetricCard(label: marketText(context, 'Customer rating', 'تقييم العملاء'), value: store == null ? '—' : store.rating.toStringAsFixed(1), icon: Icons.star_outline_rounded, color: const Color(0xFFD3A13A)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 25),
                  Text(marketText(context, 'Quick actions', 'إجراءات سريعة'), style: const TextStyle(color: marketplaceInk, fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _QuickAction(label: marketText(context, 'Add a product', 'إضافة منتج'), icon: Icons.add_box_outlined, onTap: () => _showAddProduct(context)),
                      _QuickAction(label: marketText(context, 'Review store orders', 'مراجعة الطلبات'), icon: Icons.receipt_long_outlined, onTap: () => onNavigate(2)),
                      _QuickAction(label: marketText(context, 'Update stock', 'تحديث المخزون'), icon: Icons.inventory_outlined, onTap: () => onNavigate(1)),
                    ],
                  ),
                  const SizedBox(height: 23),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: const Color(0xFFEAF4F2), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: marketplaceTeal, size: 20),
                        const SizedBox(width: 9),
                        Expanded(child: Text(marketText(context, 'Shop Wave keeps each seller workspace scoped to its own store. Product and inventory actions in this prototype check store ownership in the app layer.', 'تعرض لوحة كل بائع بيانات متجره فقط. تتحقق النسخة الأولية من ملكية المنتجات والمخزون داخل التطبيق.'), style: const TextStyle(color: marketplaceInk, fontSize: 11, height: 1.5))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddProduct(BuildContext context) async {
    await showDialog<void>(context: context, builder: (_) => const _ProductEditorDialog());
  }
}

class _SellerCatalogScreen extends StatelessWidget {
  const _SellerCatalogScreen();

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        final products = market.currentSellerProducts;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarketplacePageTitle(
                    title: marketText(context, 'My catalog', 'كتالوجي'),
                    subtitle: marketText(context, 'Only Nova Tech listings are available to this seller workspace.', 'تقتصر هذه اللوحة على منتجات متجر نوفا للتقنية.'),
                    trailing: FilledButton.icon(
                      onPressed: () => showDialog<void>(context: context, builder: (_) => const _ProductEditorDialog()),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(marketText(context, 'Add product', 'إضافة منتج')),
                    ),
                  ),
                  if (products.isEmpty)
                    MarketplaceEmptyState(icon: Icons.inventory_2_outlined, title: marketText(context, 'No products in your catalog', 'لا توجد منتجات في الكتالوج'), description: marketText(context, 'Add the first listing to your independent store.', 'أضف أول منتج إلى متجرك المستقل.'))
                  else
                    ...products.map((product) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SellerProductTile(product: product),
                        )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SellerProductTile extends StatelessWidget {
  final Product product;

  const _SellerProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final market = context.read<MarketplaceProvider>();
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(17)),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: MarketplaceImage(imageUrl: product.imageUrl, width: 65, height: 65, fallbackIcon: Icons.inventory_2_outlined)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(productTitle(context, product), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: marketplaceInk, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${money(product.price)} · ${marketText(context, 'Stock', 'المخزون')}: ${product.stockQuantity}', style: const TextStyle(color: marketplaceMuted, fontSize: 10)),
                const SizedBox(height: 5),
                StatusPill(label: product.isActive ? marketText(context, 'Visible', 'ظاهر') : marketText(context, 'Hidden', 'مخفي'), color: product.isActive ? marketplaceTeal : marketplaceCoral),
              ],
            ),
          ),
          IconButton(
            tooltip: marketText(context, 'Edit price and inventory', 'تعديل السعر والمخزون'),
            onPressed: () => showDialog<void>(context: context, builder: (_) => _ProductEditorDialog(product: product)),
            icon: const Icon(Icons.edit_outlined, color: marketplaceTeal),
          ),
          IconButton(
            tooltip: product.isActive ? marketText(context, 'Hide product', 'إخفاء المنتج') : marketText(context, 'Show product', 'إظهار المنتج'),
            onPressed: () {
              final saved = market.updateOwnProduct(
                productId: product.id,
                price: product.price,
                stockQuantity: product.stockQuantity,
                isActive: !product.isActive && product.stockQuantity > 0,
              );
              if (!saved) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(marketText(context, 'This product is outside your store.', 'هذا المنتج لا يتبع لمتجرك.'))));
              }
            },
            icon: Icon(product.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: marketplaceMuted),
          ),
        ],
      ),
    );
  }
}

class _ProductEditorDialog extends StatefulWidget {
  final Product? product;

  const _ProductEditorDialog({this.product});

  @override
  State<_ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<_ProductEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _description;
  late final TextEditingController _imageUrl;
  late String _categoryId;
  bool _isActive = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _price = TextEditingController(text: product?.price.toStringAsFixed(2) ?? '');
    _stock = TextEditingController(text: product?.stockQuantity.toString() ?? '1');
    _description = TextEditingController(text: product?.description ?? '');
    _imageUrl = TextEditingController(text: product?.imageUrl ?? '');
    _categoryId = product?.categoryId ?? 'smartphones';
    _isActive = product?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    _description.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(editing ? marketText(context, 'Edit listing', 'تعديل المنتج') : marketText(context, 'Add a product', 'إضافة منتج'), style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: _name, decoration: InputDecoration(labelText: marketText(context, 'Product name', 'اسم المنتج')), validator: _required),
                const SizedBox(height: 10),
                Row(children: [Expanded(child: TextFormField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: marketText(context, 'Price (USD)', 'السعر (USD)')), validator: _nonNegativeNumber)), const SizedBox(width: 10), Expanded(child: TextFormField(controller: _stock, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: marketText(context, 'Stock quantity', 'كمية المخزون')), validator: _nonNegativeInteger))]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: InputDecoration(labelText: marketText(context, 'Category', 'الفئة')),
                  items: context.read<MarketplaceProvider>().categories.map((category) => DropdownMenuItem(value: category.id, child: Text(categoryTitle(context, category)))).toList(),
                  onChanged: (value) => setState(() => _categoryId = value ?? 'smartphones'),
                ),
                const SizedBox(height: 10),
                TextFormField(controller: _description, maxLines: 2, decoration: InputDecoration(labelText: marketText(context, 'Description', 'الوصف'))),
                const SizedBox(height: 10),
                TextFormField(controller: _imageUrl, decoration: InputDecoration(labelText: marketText(context, 'Image URL (optional)', 'رابط الصورة (اختياري)'))),
                if (editing)
                  SwitchListTile.adaptive(
                    value: _isActive,
                    contentPadding: EdgeInsets.zero,
                    activeColor: marketplaceTeal,
                    title: Text(marketText(context, 'Visible in marketplace', 'ظاهر في السوق'), style: const TextStyle(fontSize: 12)),
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(marketText(context, 'Cancel', 'إلغاء'))),
        FilledButton(onPressed: _save, child: Text(marketText(context, 'Save listing', 'حفظ المنتج'))),
      ],
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? marketText(context, 'Required field', 'هذا الحقل مطلوب') : null;

  String? _nonNegativeNumber(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || number < 0 ? marketText(context, 'Enter a valid non-negative price.', 'أدخل سعراً صحيحاً غير سالب.') : null;
  }

  String? _nonNegativeInteger(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 0 ? marketText(context, 'Enter a valid stock quantity.', 'أدخل كمية مخزون صحيحة.') : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final market = context.read<MarketplaceProvider>();
    final price = double.parse(_price.text);
    final stock = int.parse(_stock.text);
    final saved = widget.product == null
        ? market.createOwnProduct(
            name: _name.text,
            price: price,
            stockQuantity: stock,
            categoryId: _categoryId,
            description: _description.text,
            imageUrl: _imageUrl.text,
          )
        : market.updateOwnProduct(
            productId: widget.product!.id,
            name: _name.text,
            price: price,
            stockQuantity: stock,
            categoryId: _categoryId,
            description: _description.text,
            imageUrl: _imageUrl.text,
            isActive: _isActive && stock > 0,
          );
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _error = marketText(context, 'Could not save this listing. Check your store permissions and values.', 'تعذر حفظ المنتج. تحقق من صلاحية المتجر والقيم المدخلة.'));
    }
  }
}

class _SellerOrdersScreen extends StatelessWidget {
  const _SellerOrdersScreen();

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        final orders = market.currentSellerOrders;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarketplacePageTitle(title: marketText(context, 'Orders for my store', 'طلبات متجري'), subtitle: marketText(context, 'These are sub-orders routed only to Nova Tech.', 'هذه الطلبات الفرعية تخص متجر نوفا للتقنية فقط.')),
                  if (orders.isEmpty)
                    MarketplaceEmptyState(icon: Icons.receipt_long_outlined, title: marketText(context, 'No store orders yet', 'لا توجد طلبات للمتجر بعد'), description: marketText(context, 'When customers check out items from your store, the store-specific orders will appear here.', 'ستظهر هنا الطلبات الخاصة بمتجرك عندما يشتري العملاء منتجاتك.'))
                  else
                    ...orders.map((order) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _SellerOrderCard(order: order))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SellerOrderCard extends StatelessWidget {
  final StoreOrder order;

  const _SellerOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final market = context.read<MarketplaceProvider>();
    final parent = market.orderById(order.parentOrderId);
    final nextAction = _nextAction(context, order.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(order.id, style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800, fontSize: 13)), const SizedBox(height: 3), Text('${marketText(context, 'Parent', 'الرئيسي')} ${order.parentOrderId} · ${parent?.customerName ?? marketText(context, 'Guest', 'زائر')}', style: const TextStyle(color: marketplaceMuted, fontSize: 10))])), StatusPill(label: orderStatusTitle(context, order.status), color: _statusColor(order.status))]),
          const Divider(height: 23),
          ...order.lines.map((line) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(children: [Expanded(child: Text('${line.quantity} × ${isArabic(context) && line.productNameAr.isNotEmpty ? line.productNameAr : line.productName}', style: const TextStyle(color: marketplaceInk, fontSize: 11, fontWeight: FontWeight.w600))), Text(money(line.total), style: const TextStyle(color: marketplaceInk, fontSize: 11, fontWeight: FontWeight.w700))]))),
          const Divider(height: 20),
          Row(children: [Text(marketText(context, 'Store-order total', 'إجمالي طلب المتجر'), style: const TextStyle(color: marketplaceMuted, fontSize: 11)), const Spacer(), Text(money(order.subtotal), style: const TextStyle(color: marketplaceTeal, fontSize: 14, fontWeight: FontWeight.w800))]),
          if (parent != null) ...[
            const SizedBox(height: 5),
            Text('${parent.customerPhone} · ${parent.deliveryAddress}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: marketplaceMuted, fontSize: 10)),
          ],
          if (nextAction != null) ...[
            const SizedBox(height: 13),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: () {
                  final changed = market.advanceSellerOrder(order.parentOrderId, order.id);
                  if (!changed) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(marketText(context, 'This order is outside your store.', 'هذا الطلب لا يتبع لمتجرك.'))));
                  }
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                label: Text(nextAction),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _nextAction(BuildContext context, StoreOrderStatus status) {
    switch (status) {
      case StoreOrderStatus.awaitingSeller:
        return marketText(context, 'Accept order', 'قبول الطلب');
      case StoreOrderStatus.accepted:
        return marketText(context, 'Start preparing', 'بدء التجهيز');
      case StoreOrderStatus.preparing:
        return marketText(context, 'Mark ready', 'تحديد كجاهز');
      case StoreOrderStatus.ready:
        return marketText(context, 'Complete order', 'إكمال الطلب');
      case StoreOrderStatus.completed:
      case StoreOrderStatus.cancelled:
      case StoreOrderStatus.declined:
        return null;
    }
  }

  Color _statusColor(StoreOrderStatus status) =>
      status == StoreOrderStatus.cancelled || status == StoreOrderStatus.declined
          ? marketplaceCoral
          : marketplaceTeal;
}

class _SellerStoreProfileScreen extends StatelessWidget {
  const _SellerStoreProfileScreen();

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        final store = market.currentSellerStore;
        if (store == null) {
          return MarketplaceEmptyState(icon: Icons.store_outlined, title: marketText(context, 'No store assigned', 'لا يوجد متجر مرتبط'), description: marketText(context, 'A platform administrator must approve your seller application first.', 'يجب أن يعتمد مدير المنصة طلب الانضمام أولاً.'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarketplacePageTitle(title: marketText(context, 'Store profile', 'ملف المتجر'), subtitle: marketText(context, 'Your storefront identity and order-acceptance status.', 'بيانات واجهة متجرك وحالة استقبال الطلبات.')),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(19),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(19)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [StoreAvatar(store: store, size: 58), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(storeTitle(context, store), style: const TextStyle(color: marketplaceInk, fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${store.city} · ${categoryTitleById(context, store.categoryId)}', style: const TextStyle(color: marketplaceMuted, fontSize: 11))])), IconButton(onPressed: () => showDialog<void>(context: context, builder: (_) => _StoreProfileEditor(store: store)), icon: const Icon(Icons.edit_outlined, color: marketplaceTeal))]),
                        const Divider(height: 25),
                        Text(isArabic(context) && store.descriptionAr.isNotEmpty ? store.descriptionAr : store.description, style: const TextStyle(color: marketplaceMuted, fontSize: 12, height: 1.5)),
                        const SizedBox(height: 8),
                        Row(children: [const Icon(Icons.star_rounded, size: 16, color: Color(0xFFE3A72F)), const SizedBox(width: 4), Text('${store.rating.toStringAsFixed(1)} · ${store.reviewCount} ${marketText(context, 'customer reviews', 'تقييم من العملاء')}', style: const TextStyle(color: marketplaceInk, fontSize: 11, fontWeight: FontWeight.w600))]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 6, 13, 6),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(16)),
                    child: SwitchListTile.adaptive(
                      value: store.isOpen,
                      activeColor: marketplaceTeal,
                      contentPadding: EdgeInsets.zero,
                      title: Text(marketText(context, 'Accepting new orders', 'استقبال طلبات جديدة'), style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: Text(store.isOpen ? marketText(context, 'Your active products can be purchased.', 'يمكن شراء المنتجات النشطة.') : marketText(context, 'Your store is hidden from shopping until reopened.', 'متجرك مخفي عن التسوق حتى إعادة فتحه.'), style: const TextStyle(color: marketplaceMuted, fontSize: 10)),
                      onChanged: (value) => market.setOwnStoreOpen(value),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(marketText(context, 'Store privacy', 'خصوصية المتجر'), style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(marketText(context, 'Your product catalog, stock, and store sub-orders are kept in this seller workspace. Other sellers do not see this store’s management data.', 'يقتصر هذا الحساب على كتالوج متجرك ومخزونه وطلباته الفرعية. لا يرى البائعون الآخرون بيانات الإدارة الخاصة بمتجرك.'), style: const TextStyle(color: marketplaceMuted, fontSize: 12, height: 1.5)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StoreProfileEditor extends StatefulWidget {
  final MarketplaceStore store;

  const _StoreProfileEditor({required this.store});

  @override
  State<_StoreProfileEditor> createState() => _StoreProfileEditorState();
}

class _StoreProfileEditorState extends State<_StoreProfileEditor> {
  late final TextEditingController _name = TextEditingController(text: widget.store.name);
  late final TextEditingController _description = TextEditingController(text: widget.store.description);
  late final TextEditingController _city = TextEditingController(text: widget.store.city);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(marketText(context, 'Edit store profile', 'تعديل ملف المتجر'), style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: InputDecoration(labelText: marketText(context, 'Store name', 'اسم المتجر'))),
            const SizedBox(height: 10),
            TextField(controller: _description, maxLines: 3, decoration: InputDecoration(labelText: marketText(context, 'Description', 'الوصف'))),
            const SizedBox(height: 10),
            TextField(controller: _city, decoration: InputDecoration(labelText: marketText(context, 'City', 'المدينة'))),
            if (_error != null) ...[const SizedBox(height: 7), Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(marketText(context, 'Cancel', 'إلغاء'))),
        FilledButton(
          onPressed: () {
            final saved = context.read<MarketplaceProvider>().updateOwnStore(name: _name.text, description: _description.text, city: _city.text);
            if (saved) {
              Navigator.pop(context);
            } else {
              setState(() => _error = marketText(context, 'Only your own store profile can be changed.', 'يمكن تعديل ملف متجرك فقط.'));
            }
          },
          child: Text(marketText(context, 'Save', 'حفظ')),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAction({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label));
  }
}
