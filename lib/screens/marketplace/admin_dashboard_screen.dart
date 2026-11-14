import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../localization/marketplace_copy.dart';
import '../../models/marketplace_models.dart';
import '../../models/product.dart';
import '../../providers/marketplace_provider.dart';
import '../../widgets/marketplace_widgets.dart';

class AdminWorkspaceScreen extends StatelessWidget {
  final int section;
  final ValueChanged<int> onNavigate;

  const AdminWorkspaceScreen({
    super.key,
    required this.section,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case 0:
        return _AdminOverview(onNavigate: onNavigate);
      case 1:
        return const _SellerApplicationsScreen();
      case 2:
        return const _MarketplaceModerationScreen();
      case 3:
        return const _AdminAuditScreen();
      default:
        return _AdminOverview(onNavigate: onNavigate);
    }
  }
}

class _AdminOverview extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const _AdminOverview({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarketplacePageTitle(
                    title: marketText(context, 'Platform overview', 'نظرة عامة على المنصة'),
                    subtitle: marketText(context, 'A central view of independent sellers, stores, catalog activity and orders.', 'إشراف مركزي على البائعين والمتاجر والكتالوج والطلبات.'),
                    trailing: StatusPill(label: marketText(context, 'Admin preview', 'معاينة المدير'), color: const Color(0xFF4779B6)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF243F58), Color(0xFF176E68)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 26)),
                        const SizedBox(width: 13),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(marketText(context, 'One marketplace, independent stores', 'سوق موحد ومتاجر مستقلة'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(marketText(context, 'Review sellers centrally while each seller manages only their own store.', 'راجع طلبات البائعين مركزياً مع بقاء إدارة كل متجر بيد صاحبه.'), style: const TextStyle(color: Colors.white70, fontSize: 11))])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final count = constraints.maxWidth >= 800 ? 4 : 2;
                      return GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: count, crossAxisSpacing: 12, mainAxisSpacing: 12, mainAxisExtent: 126),
                        children: [
                          MarketplaceMetricCard(label: marketText(context, 'Active stores', 'المتاجر النشطة'), value: '${market.activeStoreCount}', icon: Icons.storefront_outlined),
                          MarketplaceMetricCard(label: marketText(context, 'Pending sellers', 'طلبات البائعين'), value: '${market.pendingApplicationCount}', icon: Icons.person_search_outlined, color: const Color(0xFF4779B6)),
                          MarketplaceMetricCard(label: marketText(context, 'Active listings', 'المنتجات النشطة'), value: '${market.catalogProductCount}', icon: Icons.inventory_2_outlined, color: const Color(0xFF8B6BB2)),
                          MarketplaceMetricCard(label: marketText(context, 'Demo sales', 'مبيعات تجريبية'), value: money(market.demoSalesTotal), icon: Icons.payments_outlined, color: marketplaceCoral, note: marketText(context, 'sandbox', 'تجريبي')),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Text(marketText(context, 'Needs attention', 'يحتاج إلى المراجعة'), style: const TextStyle(color: marketplaceInk, fontSize: 17, fontWeight: FontWeight.w800))),
                      TextButton(onPressed: () => onNavigate(1), child: Text(marketText(context, 'View requests', 'عرض الطلبات'))),
                    ],
                  ),
                  if (market.pendingApplicationCount == 0)
                    Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(15)), child: Text(marketText(context, 'No seller applications are waiting for review.', 'لا توجد طلبات بائعين بانتظار المراجعة.'), style: const TextStyle(color: marketplaceMuted, fontSize: 12)))
                  else
                    ...market.sellerApplications.where((application) => application.status == SellerApplicationStatus.pending).take(3).map((application) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _PendingApplicationPreview(application: application, onReview: () => onNavigate(1)),
                        )),
                  const SizedBox(height: 22),
                  Text(marketText(context, 'Recent platform actions', 'أحدث إجراءات المنصة'), style: const TextStyle(color: marketplaceInk, fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (market.auditEvents.isEmpty)
                    Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(15)), child: Text(marketText(context, 'Administrative actions will appear here.', 'ستظهر الإجراءات الإدارية هنا.'), style: const TextStyle(color: marketplaceMuted, fontSize: 12)))
                  else
                    ...market.auditEvents.take(4).map((event) => _AuditEventTile(event: event)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SellerApplicationsScreen extends StatelessWidget {
  const _SellerApplicationsScreen();

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        final applications = market.sellerApplications;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarketplacePageTitle(title: marketText(context, 'Seller applications', 'طلبات الانضمام كبائع'), subtitle: marketText(context, 'Approve, decline, or review incoming requests to join the marketplace.', 'اعتمد طلبات الانضمام للسوق أو ارفضها وراجع بياناتها.')),
                  if (applications.isEmpty)
                    MarketplaceEmptyState(icon: Icons.fact_check_outlined, title: marketText(context, 'No applications yet', 'لا توجد طلبات'), description: marketText(context, 'Seller applications will appear here for a platform review.', 'ستظهر طلبات البائعين هنا لمراجعتها من إدارة المنصة.'))
                  else
                    ...applications.map((application) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ApplicationCard(application: application),
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

class _ApplicationCard extends StatelessWidget {
  final SellerApplication application;

  const _ApplicationCard({required this.application});

  @override
  Widget build(BuildContext context) {
    final pending = application.status == SellerApplicationStatus.pending;
    final market = context.read<MarketplaceProvider>();
    final category = market.categoryById(application.categoryId);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 45, height: 45, decoration: BoxDecoration(color: const Color(0xFFEAF4F2), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.store_mall_directory_outlined, color: marketplaceTeal)),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(application.storeName, style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800, fontSize: 14)), const SizedBox(height: 3), Text('${application.sellerName} · ${application.city}', style: const TextStyle(color: marketplaceMuted, fontSize: 11))])),
              StatusPill(label: applicationStatusTitle(context, application.status), color: pending ? marketplaceCoral : marketplaceTeal),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(spacing: 9, runSpacing: 6, children: [StatusPill(label: category == null ? application.categoryId : categoryTitle(context, category)), Text('${marketText(context, 'Submitted', 'تاريخ الطلب')}: ${application.submittedAt.toLocal().toString().substring(0, 10)}', style: const TextStyle(color: marketplaceMuted, fontSize: 10))]),
          if (application.note.isNotEmpty) ...[const SizedBox(height: 10), Text(application.note, style: const TextStyle(color: marketplaceMuted, fontSize: 12, height: 1.45))],
          if (pending) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _decide(context, market, approve: false), icon: const Icon(Icons.close_rounded, size: 17), label: Text(marketText(context, 'Decline', 'رفض')))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton.icon(onPressed: () => _decide(context, market, approve: true), icon: const Icon(Icons.check_rounded, size: 17), label: Text(marketText(context, 'Approve seller', 'اعتماد البائع')))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _decide(BuildContext context, MarketplaceProvider market, {required bool approve}) {
    final changed = market.reviewSellerApplication(application.id, approve: approve);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(changed
          ? approve
              ? marketText(context, 'Seller approved. Their independent store is now listed.', 'تم اعتماد البائع وإضافة متجره المستقل.')
              : marketText(context, 'Seller application declined.', 'تم رفض طلب البائع.')
          : marketText(context, 'This request is no longer pending.', 'لم يعد هذا الطلب قيد المراجعة.'))),
    );
  }
}

class _MarketplaceModerationScreen extends StatelessWidget {
  const _MarketplaceModerationScreen();

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        final stores = market.stores;
        final products = market.products;
        final orders = market.allOrders;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarketplacePageTitle(title: marketText(context, 'Marketplace management', 'إدارة السوق'), subtitle: marketText(context, 'Review stores and listings, and inspect parent and store-specific orders.', 'راجع المتاجر والمنتجات والطلبات الرئيسية والفرعية.')),
                  Text(marketText(context, 'Independent stores', 'المتاجر المستقلة'), style: const TextStyle(color: marketplaceInk, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 9),
                  ...stores.map((store) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _StoreModerationTile(store: store),
                      )),
                  const SizedBox(height: 20),
                  Text(marketText(context, 'Product listings', 'منتجات السوق'), style: const TextStyle(color: marketplaceInk, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 9),
                  ...products.map((product) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ProductModerationTile(product: product),
                      )),
                  const SizedBox(height: 20),
                  Text(marketText(context, 'Marketplace orders', 'طلبات السوق'), style: const TextStyle(color: marketplaceInk, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 9),
                  if (orders.isEmpty)
                    Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(15)), child: Text(marketText(context, 'No demo orders have been placed yet.', 'لم يتم إنشاء طلبات تجريبية بعد.'), style: const TextStyle(color: marketplaceMuted, fontSize: 12)))
                  else
                    ...orders.map((order) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _ParentOrderTile(order: order),
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

class _StoreModerationTile extends StatelessWidget {
  final MarketplaceStore store;

  const _StoreModerationTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final market = context.read<MarketplaceProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          StoreAvatar(store: store, size: 42),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(storeTitle(context, store), style: const TextStyle(color: marketplaceInk, fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${store.city} · ${store.sellerId}', style: const TextStyle(color: marketplaceMuted, fontSize: 10))])),
          StatusPill(label: storeStatusTitle(context, store.status), color: store.status == StoreStatus.active ? marketplaceTeal : marketplaceCoral),
          const SizedBox(width: 6),
          IconButton(
            tooltip: store.status == StoreStatus.suspended ? marketText(context, 'Reactivate store', 'إعادة تفعيل المتجر') : marketText(context, 'Suspend store', 'إيقاف المتجر'),
            onPressed: () => market.setStoreSuspended(store.id, suspended: store.status != StoreStatus.suspended),
            icon: Icon(store.status == StoreStatus.suspended ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded, color: store.status == StoreStatus.suspended ? marketplaceTeal : marketplaceCoral),
          ),
        ],
      ),
    );
  }
}

class _ProductModerationTile extends StatelessWidget {
  final Product product;

  const _ProductModerationTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final market = context.read<MarketplaceProvider>();
    final store = market.storeById(product.storeId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(9), child: MarketplaceImage(imageUrl: product.imageUrl, width: 42, height: 42, fallbackIcon: Icons.inventory_2_outlined)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(productTitle(context, product), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: marketplaceInk, fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text('${store == null ? product.storeName : storeTitle(context, store)} · ${money(product.price)}', style: const TextStyle(color: marketplaceMuted, fontSize: 10))])),
          StatusPill(label: product.isActive ? marketText(context, 'Visible', 'ظاهر') : marketText(context, 'Hidden', 'مخفي'), color: product.isActive ? marketplaceTeal : marketplaceCoral),
          IconButton(
            tooltip: product.isActive ? marketText(context, 'Hide listing', 'إخفاء المنتج') : marketText(context, 'Restore listing', 'إعادة إظهار المنتج'),
            onPressed: () => market.setProductModeration(product.id, visible: !product.isActive),
            icon: Icon(product.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: marketplaceMuted),
          ),
        ],
      ),
    );
  }
}

class _ParentOrderTile extends StatelessWidget {
  final MarketplaceOrder order;

  const _ParentOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final market = context.read<MarketplaceProvider>();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text('${order.id} · ${order.customerName}', style: const TextStyle(color: marketplaceInk, fontSize: 12, fontWeight: FontWeight.w800))), Text(money(order.total), style: const TextStyle(color: marketplaceTeal, fontSize: 12, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 8),
          ...order.storeOrders.map((child) {
            final store = market.storeById(child.storeId);
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [const Icon(Icons.subdirectory_arrow_right_rounded, size: 15, color: marketplaceMuted), const SizedBox(width: 4), Expanded(child: Text(store == null ? child.storeId : storeTitle(context, store), style: const TextStyle(color: marketplaceMuted, fontSize: 10))), StatusPill(label: orderStatusTitle(context, child.status), color: marketplaceTeal)]),
            );
          }),
        ],
      ),
    );
  }
}

class _AdminAuditScreen extends StatelessWidget {
  const _AdminAuditScreen();

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketplaceProvider>(
      builder: (context, market, _) {
        final events = market.auditEvents;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 930),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarketplacePageTitle(title: marketText(context, 'Platform activity log', 'سجل نشاط المنصة'), subtitle: marketText(context, 'A readable history of demo administrative and order-management actions.', 'سجل قابل للمراجعة لإجراءات الإدارة والطلبات التجريبية.')),
                  if (events.isEmpty)
                    MarketplaceEmptyState(icon: Icons.history_rounded, title: marketText(context, 'No activity recorded yet', 'لا يوجد نشاط مسجل بعد'), description: marketText(context, 'Actions such as seller approvals and store moderation will be listed here.', 'ستظهر هنا إجراءات مثل اعتماد البائعين ومراجعة المتاجر.'))
                  else
                    ...events.map((event) => _AuditEventTile(event: event)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AuditEventTile extends StatelessWidget {
  final MarketplaceAuditEvent event;

  const _AuditEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 35, height: 35, decoration: BoxDecoration(color: const Color(0xFFEAF4F2), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.history_rounded, color: marketplaceTeal, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(event.action, style: const TextStyle(color: marketplaceInk, fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text('${event.actor} · ${event.target}', style: const TextStyle(color: marketplaceMuted, fontSize: 10))])),
          Text(event.createdAt.toLocal().toString().substring(0, 16), style: const TextStyle(color: marketplaceMuted, fontSize: 9)),
        ],
      ),
    );
  }
}

class _PendingApplicationPreview extends StatelessWidget {
  final SellerApplication application;
  final VoidCallback onReview;

  const _PendingApplicationPreview({required this.application, required this.onReview});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: marketplaceLine), borderRadius: BorderRadius.circular(15)),
      child: Row(children: [const Icon(Icons.storefront_outlined, color: marketplaceTeal), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(application.storeName, style: const TextStyle(color: marketplaceInk, fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text('${application.sellerName} · ${application.city}', style: const TextStyle(color: marketplaceMuted, fontSize: 10))])), TextButton(onPressed: onReview, child: Text(marketText(context, 'Review', 'مراجعة')))]),
    );
  }
}
