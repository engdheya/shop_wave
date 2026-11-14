import 'package:flutter/widgets.dart';

import '../models/marketplace_models.dart';
import '../models/product.dart';

bool isArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

String marketText(BuildContext context, String english, String arabic) =>
    isArabic(context) ? arabic : english;

String productTitle(BuildContext context, Product product) =>
    product.displayName(arabic: isArabic(context));

String productDescription(BuildContext context, Product product) =>
    product.displayDescription(arabic: isArabic(context));

String storeTitle(BuildContext context, MarketplaceStore store) =>
    isArabic(context) && store.nameAr.isNotEmpty ? store.nameAr : store.name;

String categoryTitle(BuildContext context, MarketplaceCategory category) =>
    isArabic(context) ? category.nameAr : category.name;

String categoryTitleById(BuildContext context, String categoryId) {
  const categories = <String, List<String>>{
    'smartphones': ['Phones', 'هواتف'],
    'audio': ['Audio', 'صوتيات'],
    'home': ['Home & Living', 'المنزل والمعيشة'],
    'fashion': ['Fashion', 'أزياء'],
    'beauty': ['Beauty & Care', 'الجمال والعناية'],
    'gaming': ['Gaming', 'الألعاب'],
  };
  final labels = categories[categoryId] ?? ['Marketplace', 'السوق'];
  return isArabic(context) ? labels[1] : labels[0];
}

String roleTitle(BuildContext context, MarketplaceRole role) {
  switch (role) {
    case MarketplaceRole.customer:
      return marketText(context, 'Customer', 'عميل');
    case MarketplaceRole.seller:
      return marketText(context, 'Seller workspace', 'لوحة البائع');
    case MarketplaceRole.admin:
      return marketText(context, 'Platform admin', 'إدارة المنصة');
  }
}

String storeStatusTitle(BuildContext context, StoreStatus status) {
  switch (status) {
    case StoreStatus.active:
      return marketText(context, 'Open', 'مفتوح');
    case StoreStatus.paused:
      return marketText(context, 'Paused', 'متوقف مؤقتاً');
    case StoreStatus.suspended:
      return marketText(context, 'Suspended', 'موقوف');
  }
}

String applicationStatusTitle(
  BuildContext context,
  SellerApplicationStatus status,
) {
  switch (status) {
    case SellerApplicationStatus.pending:
      return marketText(context, 'In review', 'قيد المراجعة');
    case SellerApplicationStatus.approved:
      return marketText(context, 'Approved', 'تمت الموافقة');
    case SellerApplicationStatus.rejected:
      return marketText(context, 'Declined', 'مرفوض');
  }
}

String orderStatusTitle(BuildContext context, StoreOrderStatus status) {
  switch (status) {
    case StoreOrderStatus.awaitingSeller:
      return marketText(context, 'Awaiting store', 'بانتظار المتجر');
    case StoreOrderStatus.accepted:
      return marketText(context, 'Accepted', 'تم القبول');
    case StoreOrderStatus.preparing:
      return marketText(context, 'Preparing', 'قيد التجهيز');
    case StoreOrderStatus.ready:
      return marketText(context, 'Ready for delivery', 'جاهز للتسليم');
    case StoreOrderStatus.completed:
      return marketText(context, 'Completed', 'مكتمل');
    case StoreOrderStatus.cancelled:
      return marketText(context, 'Cancelled', 'ملغي');
    case StoreOrderStatus.declined:
      return marketText(context, 'Declined', 'مرفوض');
  }
}

String paymentStatusTitle(BuildContext context, PaymentStatus status) {
  switch (status) {
    case PaymentStatus.sandboxApproved:
      return marketText(context, 'Test checkout', 'دفع تجريبي');
    case PaymentStatus.pending:
      return marketText(context, 'Pending', 'معلّق');
    case PaymentStatus.failed:
      return marketText(context, 'Failed', 'فشل');
  }
}

String money(double amount) => '\$${amount.toStringAsFixed(2)}';
