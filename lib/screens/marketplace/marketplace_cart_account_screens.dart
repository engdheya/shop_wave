import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../localization/marketplace_copy.dart';
import '../../models/marketplace_models.dart';
import '../../models/product.dart';
import '../../providers/marketplace_auth_provider.dart';
import '../../providers/marketplace_provider.dart';
import '../../widgets/marketplace_widgets.dart';
import 'marketplace_auth_dialog.dart';
import 'marketplace_product_detail_screen.dart';

class MarketplaceCartScreen extends StatelessWidget {
  final VoidCallback onOrderPlaced;

  const MarketplaceCartScreen({super.key, required this.onOrderPlaced});

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        final signedInCustomer =
            context.watch<MarketplaceAuthProvider>().currentUser?.role ==
                MarketplaceRole.customer;
        final groups = market.cartGroups;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarketplacePageTitle(
                    title: marketText(context, 'Your marketplace cart', 'سلتك متعددة المتاجر'),
                    subtitle: marketText(
                      context,
                      'One cart, grouped by independent store. Each store receives its own part of your order.',
                      'سلة واحدة مجمعة حسب المتجر المستقل، ويصل لكل متجر طلبه الفرعي الخاص.',
                    ),
                    trailing: market.cartItemCount == 0
                        ? null
                        : TextButton.icon(
                            onPressed: market.clearCart,
                            icon: const Icon(Icons.delete_outline_rounded, size: 17),
                            label: Text(marketText(context, 'Clear cart', 'إفراغ السلة')),
                          ),
                  ),
                  if (groups.isEmpty)
                    MarketplaceEmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: marketText(context, 'Your cart is waiting', 'سلتك بانتظار منتجاتك'),
                      description: marketText(context, 'Explore independent stores and add items from one or several shops.', 'تصفح المتاجر المستقلة وأضف منتجات من متجر واحد أو أكثر.'),
                    )
                  else ...[
                    _CartSummary(count: market.cartItemCount, storeCount: groups.length, total: market.cartSubtotal),
                    const SizedBox(height: 16),
                    ...groups.map((group) => Padding(
                          padding: const EdgeInsets.only(bottom: 13),
                          child: _StoreCartGroup(group: group),
                        )),
                    const SizedBox(height: 4),
                    _CheckoutSummary(
                      total: market.cartSubtotal,
                      requiresSignIn: !signedInCustomer,
                      onCheckout: () => _openCheckout(context),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: marketplaceTeal, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            marketText(
                              context,
                              'This demo uses a sandbox checkout only. No card details are collected and no real payment is processed.',
                              'تستخدم هذه النسخة دفعاً تجريبياً فقط. لا يتم جمع بيانات البطاقة أو تنفيذ دفعة حقيقية.',
                            ),
                            style: const TextStyle(color: marketplaceMuted, fontSize: 11, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCheckout(BuildContext context) async {
    final auth = context.read<MarketplaceAuthProvider>();
    if (!auth.isAuthenticated) {
      final signedIn = await showMarketplaceAuthDialog(context);
      if (!context.mounted || !signedIn) return;
    }
    final customer = auth.currentUser;
    if (customer == null || customer.role != MarketplaceRole.customer) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(marketText(context, 'A customer account is required to complete checkout.', 'يلزم تسجيل الدخول بحساب عميل لإتمام الشراء.'))),
        );
      }
      return;
    }

    final result = await showDialog<CheckoutResult>(
      context: context,
      builder: (_) => _CheckoutDialog(
        customerName: customer.displayName,
        customerPhone: customer.phone,
      ),
    );
    if (!context.mounted || result == null || !result.isSuccess || result.order == null) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _OrderConfirmationDialog(order: result.order!),
    );
    if (context.mounted) onOrderPlaced();
  }
}

class _CartSummary extends StatelessWidget {
  final int count;
  final int storeCount;
  final double total;

  const _CartSummary({required this.count, required this.storeCount, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: marketplaceLine),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(color: const Color(0xFFEAF4F2), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.shopping_bag_outlined, color: marketplaceTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count ${marketText(context, 'items', 'منتج')} · $storeCount ${marketText(context, 'stores', 'متاجر')}', style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 3),
                Text(marketText(context, 'Your order will be split by store', 'سيتم تقسيم طلبك حسب المتجر'), style: const TextStyle(color: marketplaceMuted, fontSize: 11)),
              ],
            ),
          ),
          Text(money(total), style: const TextStyle(color: marketplaceTeal, fontSize: 17, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _StoreCartGroup extends StatelessWidget {
  final CartStoreGroup group;

  const _StoreCartGroup({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: marketplaceLine),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              StoreAvatar(store: group.store, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(storeTitle(context, group.store), style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(marketText(context, 'Independent store · its own order', 'متجر مستقل · طلب فرعي منفصل'), style: const TextStyle(color: marketplaceMuted, fontSize: 10)),
                  ],
                ),
              ),
              Text(money(group.subtotal), style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
          const Divider(height: 22),
          ...group.lines.map((line) => _CartLineTile(line: line)),
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  final MarketplaceCartLine line;

  const _CartLineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final market = context.read<MarketplaceProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MarketplaceImage(
              imageUrl: line.product.imageUrl,
              width: 64,
              height: 64,
              fallbackIcon: Icons.inventory_2_outlined,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(productTitle(context, line.product), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 5),
                Text(money(line.product.price), style: const TextStyle(color: marketplaceTeal, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _QuantityControl(
            quantity: line.quantity,
            onDecrease: () => _changeQuantity(context, market, line, line.quantity - 1),
            onIncrease: () => _changeQuantity(context, market, line, line.quantity + 1),
          ),
          IconButton(
            tooltip: marketText(context, 'Remove', 'إزالة'),
            onPressed: () => market.removeFromCart(line.product.id),
            icon: const Icon(Icons.close_rounded, size: 19, color: marketplaceMuted),
          ),
        ],
      ),
    );
  }

  void _changeQuantity(BuildContext context, MarketplaceProvider market, MarketplaceCartLine line, int quantity) {
    final result = market.setCartQuantity(line.product.id, quantity);
    if (result == CartMutationResult.stockLimitReached) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(marketText(context, 'Only ${line.product.stockQuantity} are currently available.', 'المتاح حالياً ${line.product.stockQuantity} فقط.')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _QuantityControl({required this.quantity, required this.onDecrease, required this.onIncrease});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: marketplaceCanvas, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: onDecrease, visualDensity: VisualDensity.compact, constraints: const BoxConstraints.tightFor(width: 30, height: 34), icon: const Icon(Icons.remove_rounded, size: 15)),
          Text('$quantity', style: const TextStyle(color: marketplaceInk, fontSize: 11, fontWeight: FontWeight.w800)),
          IconButton(onPressed: onIncrease, visualDensity: VisualDensity.compact, constraints: const BoxConstraints.tightFor(width: 30, height: 34), icon: const Icon(Icons.add_rounded, size: 15)),
        ],
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  final double total;
  final bool requiresSignIn;
  final VoidCallback onCheckout;

  const _CheckoutSummary({
    required this.total,
    required this.requiresSignIn,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: marketplaceLine),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(children: [Text(marketText(context, 'Subtotal', 'المجموع الفرعي'), style: const TextStyle(color: marketplaceMuted, fontSize: 12)), const Spacer(), Text(money(total), style: const TextStyle(color: marketplaceInk, fontSize: 13, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 9),
          Row(children: [Text(marketText(context, 'Delivery', 'التوصيل'), style: const TextStyle(color: marketplaceMuted, fontSize: 12)), const Spacer(), Text(marketText(context, 'Calculated by each store', 'يحدده كل متجر'), style: const TextStyle(color: marketplaceMuted, fontSize: 11))]),
          const Divider(height: 25),
          Row(children: [Text(marketText(context, 'Order total', 'إجمالي الطلب'), style: const TextStyle(color: marketplaceInk, fontSize: 14, fontWeight: FontWeight.w800)), const Spacer(), Text(money(total), style: const TextStyle(color: marketplaceTeal, fontSize: 18, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCheckout,
              icon: Icon(requiresSignIn ? Icons.login_rounded : Icons.arrow_forward_rounded),
              label: Text(requiresSignIn
                  ? marketText(context, 'Sign in to continue', 'سجّل الدخول للمتابعة')
                  : marketText(context, 'Continue to demo checkout', 'متابعة للدفع التجريبي')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutDialog extends StatefulWidget {
  final String customerName;
  final String customerPhone;

  const _CheckoutDialog({
    required this.customerName,
    required this.customerPhone,
  });

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _addressController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customerName);
    _phoneController = TextEditingController(text: widget.customerPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(marketText(context, 'Delivery details', 'بيانات التوصيل'), style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: marketText(context, 'Full name', 'الاسم الكامل')),
                  validator: (value) => value == null || value.trim().length < 2
                      ? marketText(context, 'Enter your name.', 'أدخل الاسم.')
                      : null,
                ),
                const SizedBox(height: 11),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: marketText(context, 'Phone number', 'رقم الهاتف')),
                  validator: (value) => value == null || value.trim().length < 7
                      ? marketText(context, 'Enter a valid phone number.', 'أدخل رقم هاتف صحيحاً.')
                      : null,
                ),
                const SizedBox(height: 11),
                TextFormField(
                  controller: _addressController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: marketText(context, 'Delivery address', 'عنوان التوصيل')),
                  validator: (value) => value == null || value.trim().length < 5
                      ? marketText(context, 'Add a more complete address.', 'أدخل عنواناً مفصلاً.' )
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Align(alignment: AlignmentDirectional.centerStart, child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                ],
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(color: const Color(0xFFEAF4F2), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: marketplaceTeal, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(marketText(context, 'Sandbox only: this creates demo order records and does not charge a payment method.', 'تجريبي فقط: سيتم إنشاء سجل طلب تجريبي دون خصم أي مبلغ.'), style: const TextStyle(color: marketplaceInk, fontSize: 11, height: 1.4))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(marketText(context, 'Back', 'رجوع'))),
        FilledButton.icon(
          onPressed: _placeOrder,
          icon: const Icon(Icons.lock_open_rounded, size: 17),
          label: Text(marketText(context, 'Place test order', 'إنشاء طلب تجريبي')),
        ),
      ],
    );
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await context.read<MarketplaceProvider>().placeOrder(
          CheckoutDetails(
            customerName: _nameController.text,
            customerPhone: _phoneController.text,
            deliveryAddress: _addressController.text,
          ),
        );
    if (result.isSuccess) {
      Navigator.pop(context, result);
    } else {
      setState(() => _error = result.error ?? marketText(context, 'Unable to place this order.', 'تعذر إنشاء الطلب.'));
    }
  }
}

class _OrderConfirmationDialog extends StatelessWidget {
  final MarketplaceOrder order;

  const _OrderConfirmationDialog({required this.order});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(color: Color(0xFFEAF4F2), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: marketplaceTeal, size: 31),
            ),
            const SizedBox(height: 13),
            Text(marketText(context, 'Order created', 'تم إنشاء الطلب'), style: const TextStyle(color: marketplaceInk, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${marketText(context, 'Parent order', 'الطلب الرئيسي')} · ${order.id}', style: const TextStyle(color: marketplaceMuted, fontSize: 12)),
            const SizedBox(height: 13),
            ...order.storeOrders.map((child) {
              final store = context.read<MarketplaceProvider>().storeById(child.storeId);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_outlined, color: marketplaceTeal, size: 18),
                    const SizedBox(width: 7),
                    Expanded(child: Text(store == null ? child.storeId : storeTitle(context, store), style: const TextStyle(color: marketplaceInk, fontSize: 12, fontWeight: FontWeight.w600))),
                    Text(money(child.subtotal), style: const TextStyle(color: marketplaceInk, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
            Text(marketText(context, 'Your cart is now one parent order with a separate sub-order for each store.', 'تحولت السلة إلى طلب رئيسي وطلب فرعي مستقل لكل متجر.'), textAlign: TextAlign.center, style: const TextStyle(color: marketplaceMuted, fontSize: 11, height: 1.45)),
            const SizedBox(height: 10),
            Text(marketText(context, 'Sandbox demo — no real payment was processed.', 'نسخة تجريبية — لم يتم تنفيذ أي دفعة حقيقية.'), textAlign: TextAlign.center, style: const TextStyle(color: marketplaceCoral, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(marketText(context, 'Done', 'تم'))),
      ],
    );
  }
}

class MarketplaceAccountScreen extends StatelessWidget {
  const MarketplaceAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<MarketplaceProvider, MarketplaceAuthProvider>(
      builder: (context, market, auth, _) {
        final user = auth.currentUser;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarketplacePageTitle(
                    title: marketText(context, 'Your Shop Wave account', 'حسابك في شوب ويف'),
                    subtitle: marketText(context, 'Manage your profile, purchases, and saved products.', 'أدر ملفك الشخصي وطلباتك ومنتجاتك المحفوظة.'),
                  ),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF176E68), Color(0xFF24485D)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: Icon(
                            user == null ? Icons.person_outline_rounded : Icons.verified_user_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? marketText(context, 'Browsing as a guest', 'تتصفح كزائر'),
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user == null
                                    ? marketText(context, 'Explore freely. Sign in when you are ready to buy.', 'تصفح بحرية، وسجّل الدخول عندما تريد الشراء.')
                                    : '${user.email} · @${user.username}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (user == null) ...[
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.55))),
                            onPressed: () => showMarketplaceAuthDialog(context),
                            child: Text(marketText(context, 'Sign in', 'دخول')),
                          ),
                          const SizedBox(width: 7),
                          IconButton(
                            tooltip: marketText(context, 'Create account', 'إنشاء حساب'),
                            onPressed: () => showMarketplaceAuthDialog(context, startWithRegistration: true),
                            icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                          ),
                        ] else
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.55))),
                            onPressed: () => auth.signOut(),
                            icon: const Icon(Icons.logout_rounded, size: 17),
                            label: Text(marketText(context, 'Sign out', 'تسجيل الخروج')),
                          ),
                      ],
                    ),
                  ),
                  if (user == null) ...[
                    const SizedBox(height: 14),
                    _JoinSellerCard(
                      onApply: () => showMarketplaceAuthDialog(
                        context,
                        startWithRegistration: true,
                        initialRole: MarketplaceRole.seller,
                      ),
                    ),
                  ] else if (user.role == MarketplaceRole.customer) ...[
                    const SizedBox(height: 14),
                    _JoinSellerCard(onApply: () => _showSellerApplication(context)),
                  ],
                  const SizedBox(height: 26),
                  _AccountSectionTitle(title: marketText(context, 'Your orders', 'طلباتك'), count: market.orders.length),
                  const SizedBox(height: 10),
                  if (market.orders.isEmpty)
                    _CompactEmpty(text: marketText(context, 'No orders yet. Your order history will appear here after checkout.', 'لا توجد طلبات بعد. ستظهر هنا بعد إتمام الشراء.'))
                  else
                    ...market.orders.map((order) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CustomerOrderCard(order: order),
                        )),
                  const SizedBox(height: 21),
                  _AccountSectionTitle(title: marketText(context, 'Saved products', 'المنتجات المحفوظة'), count: market.favoriteProducts.length),
                  const SizedBox(height: 10),
                  if (market.favoriteProducts.isEmpty)
                    _CompactEmpty(text: marketText(context, 'Tap the heart on any product to save it for later.', 'اضغط على رمز القلب في أي منتج لحفظه.'))
                  else
                    ...market.favoriteProducts.map((product) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _SavedProductTile(product: product),
                        )),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFFFF6EB), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFB87028), size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(marketText(context, 'This build stores demo accounts on this device. Connect a trusted authentication service and server-side authorization before public production use.', 'يخزن هذا الإصدار الحسابات التجريبية على هذا الجهاز. يلزم ربط مصادقة موثوقة وصلاحيات خادمية قبل النشر الفعلي.'), style: const TextStyle(color: Color(0xFF725B42), fontSize: 11, height: 1.45))),
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

  Future<void> _showSellerApplication(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _SellerApplicationDialog(),
    );
    if (!context.mounted || result != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(marketText(context, 'Your seller workspace is ready. Store visibility starts after admin approval.', 'لوحة البائع جاهزة، ويظهر المتجر للعملاء بعد موافقة الإدارة.'))),
    );
  }
}

class _JoinSellerCard extends StatelessWidget {
  final VoidCallback onApply;

  const _JoinSellerCard({required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFEAF4F2), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.store_mall_directory_outlined, color: marketplaceTeal)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(marketText(context, 'Have a store of your own?', 'هل تملك متجراً؟'), style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800, fontSize: 13)), const SizedBox(height: 4), Text(marketText(context, 'Create a seller account and manage your own catalog.', 'أنشئ حساب بائع وأدر كتالوج متجرك.'), style: const TextStyle(color: marketplaceMuted, fontSize: 11))])),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onApply, child: Text(marketText(context, 'Become a seller', 'انضم كبائع'))),
        ],
      ),
    );
  }
}

class _SellerApplicationDialog extends StatefulWidget {
  const _SellerApplicationDialog();

  @override
  State<_SellerApplicationDialog> createState() => _SellerApplicationDialogState();
}

class _SellerApplicationDialogState extends State<_SellerApplicationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _storeName = TextEditingController();
  final _city = TextEditingController(text: 'Aden');
  final _description = TextEditingController();
  String _categoryId = 'smartphones';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _storeName.dispose();
    _city.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final market = context.read<MarketplaceProvider>();
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(marketText(context, 'Create your seller store', 'إنشاء متجر البائع'), style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: _storeName, decoration: InputDecoration(labelText: marketText(context, 'Store name', 'اسم المتجر')), validator: (value) => value == null || value.trim().length < 2 ? marketText(context, 'Enter a valid store name.', 'أدخل اسم متجر صحيحاً.') : null),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _categoryId,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: marketText(context, 'Main category', 'الفئة الرئيسية')),
                        items: market.categories.map((category) => DropdownMenuItem(value: category.id, child: Text(categoryTitle(context, category), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (value) => setState(() => _categoryId = value ?? 'home'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(flex: 2, child: TextFormField(controller: _city, decoration: InputDecoration(labelText: marketText(context, 'City', 'المدينة')), validator: (value) => value == null || value.trim().isEmpty ? marketText(context, 'Enter a city.', 'أدخل المدينة.') : null)),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(controller: _description, minLines: 2, maxLines: 3, decoration: InputDecoration(labelText: marketText(context, 'Store description (optional)', 'وصف المتجر (اختياري)'))),
                if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))],
                const SizedBox(height: 9),
                Text(marketText(context, 'You can manage the store immediately. Customers will see it after approval.', 'يمكنك إدارة المتجر فوراً، ويظهر للعملاء بعد الموافقة.'), style: const TextStyle(color: marketplaceMuted, fontSize: 10, height: 1.4)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(marketText(context, 'Cancel', 'إلغاء'))),
        FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(marketText(context, 'Create store', 'إنشاء المتجر'))),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final result = await context.read<MarketplaceAuthProvider>().applyForSeller(
      storeName: _storeName.text,
      storeCategoryId: _categoryId,
      storeCity: _city.text,
      storeDescription: _description.text,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = marketText(context, 'Unable to create the seller workspace for this account.', 'تعذر إنشاء لوحة البائع لهذا الحساب.');
      });
    }
  }
}

class _CustomerOrderCard extends StatelessWidget {
  final MarketplaceOrder order;

  const _CustomerOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final market = context.read<MarketplaceProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(order.id, style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800, fontSize: 13)), const SizedBox(height: 3), Text('${order.createdAt.toLocal().toString().substring(0, 16)} · ${order.itemCount} ${marketText(context, 'items', 'منتج')}', style: const TextStyle(color: marketplaceMuted, fontSize: 10))])),
              StatusPill(label: paymentStatusTitle(context, order.paymentStatus), color: marketplaceTeal),
            ],
          ),
          const Divider(height: 24),
          ...order.storeOrders.map((child) {
            final store = market.storeById(child.storeId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const Icon(Icons.storefront_outlined, color: marketplaceTeal, size: 17), const SizedBox(width: 6), Expanded(child: Text(store == null ? child.storeId : storeTitle(context, store), style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w700, fontSize: 12))), StatusPill(label: orderStatusTitle(context, child.status), color: child.status == StoreOrderStatus.cancelled || child.status == StoreOrderStatus.declined ? marketplaceCoral : marketplaceTeal)]),
                  const SizedBox(height: 6),
                  ...child.lines.map((line) => Padding(padding: const EdgeInsetsDirectional.only(start: 23, top: 3), child: Row(children: [Expanded(child: Text('${line.quantity} × ${isArabic(context) && line.productNameAr.isNotEmpty ? line.productNameAr : line.productName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: marketplaceMuted, fontSize: 10))), Text(money(line.total), style: const TextStyle(color: marketplaceInk, fontSize: 10, fontWeight: FontWeight.w600))]))),
                  if (child.canCustomerCancel) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: () => _confirmCancel(context, market, child, order.id),
                        icon: const Icon(Icons.cancel_outlined, size: 15),
                        label: Text(marketText(context, 'Cancel this store order', 'إلغاء طلب هذا المتجر')),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          const Divider(height: 15),
          Row(children: [Text(marketText(context, 'Order total', 'إجمالي الطلب'), style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800, fontSize: 12)), const Spacer(), Text(money(order.total), style: const TextStyle(color: marketplaceTeal, fontWeight: FontWeight.w800, fontSize: 14))]),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, MarketplaceProvider market, StoreOrder child, String parentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(marketText(context, 'Cancel this store order?', 'إلغاء طلب هذا المتجر؟')),
        content: Text(marketText(context, 'Only this store’s sub-order will be cancelled. Other stores in the parent order are unaffected.', 'سيتم إلغاء الطلب الفرعي لهذا المتجر فقط، دون التأثير على بقية المتاجر.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(marketText(context, 'Keep order', 'الاحتفاظ بالطلب'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(marketText(context, 'Cancel order', 'إلغاء الطلب'))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final cancelled = await market.cancelStoreOrderRemote(parentId, child.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(cancelled ? marketText(context, 'Store sub-order cancelled.', 'تم إلغاء الطلب الفرعي.') : marketText(context, 'This order can no longer be cancelled.', 'لا يمكن إلغاء هذا الطلب الآن.'))),
    );
  }
}

class _SavedProductTile extends StatelessWidget {
  final Product product;

  const _SavedProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MarketplaceProductDetailScreen(productId: product.id))),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(15)),
        child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(10), child: MarketplaceImage(imageUrl: product.imageUrl, width: 53, height: 53, fallbackIcon: Icons.inventory_2_outlined)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(productTitle(context, product), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: marketplaceInk, fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(product.displayStoreName(arabic: isArabic(context)), style: const TextStyle(color: marketplaceMuted, fontSize: 10))])), Text(money(product.price), style: const TextStyle(color: marketplaceTeal, fontSize: 12, fontWeight: FontWeight.w800)), IconButton(onPressed: () => context.read<MarketplaceProvider>().toggleFavorite(product), icon: const Icon(Icons.favorite_rounded, color: marketplaceCoral, size: 19))]),
      ),
    );
  }
}

class _AccountSectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _AccountSectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Expanded(child: Text(title, style: const TextStyle(color: marketplaceInk, fontSize: 17, fontWeight: FontWeight.w800))), Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFEAF4F2), borderRadius: BorderRadius.circular(99)), child: Text('$count', style: const TextStyle(color: marketplaceTeal, fontSize: 11, fontWeight: FontWeight.w800)))]);
  }
}

class _CompactEmpty extends StatelessWidget {
  final String text;

  const _CompactEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(15)), child: Text(text, style: const TextStyle(color: marketplaceMuted, fontSize: 12, height: 1.4)));
  }
}
