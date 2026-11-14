import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../../localization/app_localizations.dart';
import '../../localization/marketplace_copy.dart';
import '../../models/marketplace_models.dart';
import '../../providers/language_provider.dart';
import '../../providers/marketplace_auth_provider.dart';
import '../../providers/marketplace_provider.dart';
import '../../repositories/firebase_marketplace_repository.dart';
import '../../repositories/firebase_storage_repository.dart';
import '../../theme/marketplace_theme.dart';
import '../../widgets/marketplace_widgets.dart';
import 'admin_dashboard_screen.dart';
import 'customer_discovery_screens.dart';
import 'marketplace_auth_dialog.dart';
import 'marketplace_cart_account_screens.dart';
import 'seller_dashboard_screen.dart';

class MarketplaceShell extends StatefulWidget {
  const MarketplaceShell({super.key});

  @override
  State<MarketplaceShell> createState() => _MarketplaceShellState();
}

class _MarketplaceShellState extends State<MarketplaceShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer2<MarketplaceProvider, MarketplaceAuthProvider>(
      builder: (context, market, auth, _) {
        if (!auth.isInitialized) {
          return const Scaffold(
            backgroundColor: marketplaceCanvas,
            body: Center(child: CircularProgressIndicator(color: marketplaceTeal)),
          );
        }
        final destinations = _destinations(context, market.role);
        final selectedIndex = _selectedIndex.clamp(0, destinations.length - 1).toInt();
        final width = MediaQuery.sizeOf(context).width;
        final wide = width >= 920;
        final page = _page(context, market.role, selectedIndex);

        return Scaffold(
          backgroundColor: marketplaceCanvas,
          appBar: _buildAppBar(context, market, wide),
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: _selectTab,
                      extended: width >= 1260,
                      minWidth: 74,
                      minExtendedWidth: 208,
                      labelType: width >= 1260 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                      destinations: destinations
                          .map((destination) => NavigationRailDestination(
                                icon: _destinationIcon(destination.icon, destination.badgeCount),
                                selectedIcon: _destinationIcon(destination.selectedIcon, destination.badgeCount),
                                label: Text(destination.label),
                              ))
                          .toList(),
                    ),
                    const VerticalDivider(width: 1, thickness: 1, color: marketplaceLine),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1450),
                          child: page,
                        ),
                      ),
                    ),
                  ],
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1050),
                    child: page,
                  ),
                ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: _selectTab,
                  destinations: destinations
                      .map((destination) => NavigationDestination(
                            icon: _destinationIcon(destination.icon, destination.badgeCount),
                            selectedIcon: _destinationIcon(destination.selectedIcon, destination.badgeCount),
                            label: destination.label,
                          ))
                      .toList(),
                ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    MarketplaceProvider market,
    bool wide,
  ) {
    final isCustomer = market.role == MarketplaceRole.customer;
    final languageCode = Localizations.localeOf(context).languageCode;
    return AppBar(
      toolbarHeight: 68,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: marketplaceTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.waves_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Shop Wave', style: TextStyle(color: marketplaceInk, fontSize: 16, fontWeight: FontWeight.w900, height: 1.1)),
              if (wide)
                Text(
                  marketText(context, 'INDEPENDENT SHOPS · ONE MARKET', 'متاجر مستقلة · سوق واحد'),
                  style: const TextStyle(color: marketplaceMuted, fontSize: 8, letterSpacing: 0.65, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ],
      ),
      actions: [
        if (isCustomer) ...[
          IconButton(
            tooltip: marketText(context, 'Compare products', 'مقارنة المنتجات'),
            onPressed: () => _selectTab(2),
            icon: Badge(
              isLabelVisible: market.comparisonCount > 0,
              label: Text('${market.comparisonCount}'),
              child: const Icon(Icons.compare_arrows_rounded),
            ),
          ),
          IconButton(
            tooltip: marketText(context, 'Marketplace cart', 'سلة السوق'),
            onPressed: () => _selectTab(3),
            icon: Badge(
              isLabelVisible: market.cartItemCount > 0,
              label: Text('${market.cartItemCount}'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
        IconButton(
          tooltip: languageCode == 'ar' ? 'English' : 'العربية',
          onPressed: _toggleLanguage,
          icon: const Icon(Icons.language_rounded),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 12, start: 2),
          child: _identityMenu(context, wide),
        ),
      ],
      bottom: wide
          ? PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: marketplaceLine),
            )
          : null,
    );
  }

  List<_ShellDestination> _destinations(BuildContext context, MarketplaceRole role) {
    switch (role) {
      case MarketplaceRole.customer:
        return [
          _ShellDestination(marketText(context, 'Discover', 'اكتشف'), Icons.explore_outlined, Icons.explore_rounded),
          _ShellDestination(marketText(context, 'Stores', 'المتاجر'), Icons.storefront_outlined, Icons.storefront_rounded),
          _ShellDestination(marketText(context, 'Compare', 'قارن'), Icons.compare_arrows_rounded, Icons.compare_arrows_rounded, badgeCount: context.read<MarketplaceProvider>().comparisonCount),
          _ShellDestination(marketText(context, 'Cart', 'السلة'), Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, badgeCount: context.read<MarketplaceProvider>().cartItemCount),
          _ShellDestination(marketText(context, 'Account', 'حسابي'), Icons.person_outline_rounded, Icons.person_rounded),
        ];
      case MarketplaceRole.seller:
        return [
          _ShellDestination(marketText(context, 'Overview', 'الرئيسية'), Icons.dashboard_outlined, Icons.dashboard_rounded),
          _ShellDestination(marketText(context, 'Catalog', 'الكتالوج'), Icons.inventory_2_outlined, Icons.inventory_2_rounded),
          _ShellDestination(marketText(context, 'Orders', 'الطلبات'), Icons.receipt_long_outlined, Icons.receipt_long_rounded, badgeCount: context.read<MarketplaceProvider>().currentSellerOrders.length),
          _ShellDestination(marketText(context, 'My store', 'متجري'), Icons.store_outlined, Icons.store_rounded),
        ];
      case MarketplaceRole.admin:
        return [
          _ShellDestination(marketText(context, 'Overview', 'الرئيسية'), Icons.dashboard_outlined, Icons.dashboard_rounded),
          _ShellDestination(marketText(context, 'Sellers', 'البائعون'), Icons.person_search_outlined, Icons.person_search_rounded, badgeCount: context.read<MarketplaceProvider>().pendingApplicationCount),
          _ShellDestination(marketText(context, 'Manage', 'الإدارة'), Icons.tune_outlined, Icons.tune_rounded),
          _ShellDestination(marketText(context, 'Activity', 'النشاط'), Icons.history_outlined, Icons.history_rounded),
        ];
    }
  }

  Widget _page(BuildContext context, MarketplaceRole role, int index) {
    if (role == MarketplaceRole.customer) {
      switch (index) {
        case 0:
          return const MarketplaceHomeScreen();
        case 1:
          return const StoreDirectoryScreen();
        case 2:
          return MarketplaceCompareScreen(onContinueShopping: () => _selectTab(0));
        case 3:
          return MarketplaceCartScreen(onOrderPlaced: () => _selectTab(4));
        case 4:
          return const MarketplaceAccountScreen();
        default:
          return const SizedBox.shrink();
      }
    }
    if (role == MarketplaceRole.seller) {
      return SellerWorkspaceScreen(section: index, onNavigate: _selectTab);
    }
    return AdminWorkspaceScreen(section: index, onNavigate: _selectTab);
  }

  Widget _destinationIcon(IconData icon, int badgeCount) {
    return badgeCount <= 0
        ? Icon(icon)
        : Badge(label: Text(badgeCount > 99 ? '99+' : '$badgeCount'), child: Icon(icon));
  }

  IconData _roleIcon(MarketplaceRole role) {
    switch (role) {
      case MarketplaceRole.customer:
        return Icons.person_outline_rounded;
      case MarketplaceRole.seller:
        return Icons.storefront_outlined;
      case MarketplaceRole.admin:
        return Icons.admin_panel_settings_outlined;
    }
  }

  Future<void> _toggleLanguage() async {
    final current = Localizations.localeOf(context).languageCode;
    await context.read<LanguageProvider>().setLanguage(current == 'ar' ? 'en' : 'ar');
  }

  Widget _identityMenu(BuildContext context, bool wide) {
    final auth = context.watch<MarketplaceAuthProvider>();
    final user = auth.currentUser;
    final role = user?.role ?? MarketplaceRole.customer;
    return PopupMenuButton<String>(
      tooltip: marketText(context, 'Account and sign in', 'الحساب وتسجيل الدخول'),
      onSelected: (action) => _handleIdentityAction(context, action),
      itemBuilder: (menuContext) => [
        if (user == null) ...[
          PopupMenuItem(
            value: 'sign-in',
            child: _identityMenuItem(Icons.login_rounded, marketText(menuContext, 'Sign in', 'تسجيل الدخول')),
          ),
          PopupMenuItem(
            value: 'register-customer',
            child: _identityMenuItem(Icons.person_add_alt_1_rounded, marketText(menuContext, 'Create customer account', 'إنشاء حساب عميل')),
          ),
          PopupMenuItem(
            value: 'register-seller',
            child: _identityMenuItem(Icons.storefront_outlined, marketText(menuContext, 'Open a seller store', 'إنشاء حساب بائع ومتجر')),
          ),
        ] else ...[
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName, style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${roleTitle(menuContext, user.role)} · ${user.username}', style: const TextStyle(color: marketplaceMuted, fontSize: 10)),
              ],
            ),
          ),
          if (role == MarketplaceRole.customer)
            PopupMenuItem(
              value: 'account',
              child: _identityMenuItem(Icons.person_outline_rounded, marketText(menuContext, 'My account', 'حسابي')),
            ),
          PopupMenuItem(
            value: 'sign-out',
            child: _identityMenuItem(Icons.logout_rounded, marketText(menuContext, 'Sign out', 'تسجيل الخروج')),
          ),
        ],
      ],
      child: wide
          ? Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFEAF4F2), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_roleIcon(role), color: marketplaceTeal, size: 18),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      user?.displayName ?? marketText(context, 'Sign in', 'دخول'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: marketplaceTeal, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.expand_more_rounded, color: marketplaceTeal, size: 17),
                ],
              ),
            )
          : Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: const Color(0xFFEAF4F2), borderRadius: BorderRadius.circular(12)),
              child: Icon(_roleIcon(role), color: marketplaceTeal, size: 19),
            ),
    );
  }

  Widget _identityMenuItem(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 18, color: marketplaceTeal),
          const SizedBox(width: 9),
          Text(label),
        ],
      );

  Future<void> _handleIdentityAction(BuildContext context, String action) async {
    final auth = context.read<MarketplaceAuthProvider>();
    var success = false;
    switch (action) {
      case 'sign-in':
        success = await showMarketplaceAuthDialog(context);
        break;
      case 'register-customer':
        success = await showMarketplaceAuthDialog(
          context,
          startWithRegistration: true,
          initialRole: MarketplaceRole.customer,
        );
        break;
      case 'register-seller':
        success = await showMarketplaceAuthDialog(
          context,
          startWithRegistration: true,
          initialRole: MarketplaceRole.seller,
        );
        break;
      case 'account':
        _selectTab(4);
        return;
      case 'sign-out':
        await auth.signOut();
        success = true;
        break;
    }
    if (success && mounted) setState(() => _selectedIndex = 0);
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
  }
}

class _ShellDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badgeCount;

  const _ShellDestination(
    this.label,
    this.icon,
    this.selectedIcon, {
    this.badgeCount = 0,
  });
}

class ShopWaveApp extends StatelessWidget {
  const ShopWaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseMarketplaceRepository>(
          create: (_) => FirebaseMarketplaceRepository(),
        ),
        Provider<FirebaseStorageRepository>(
          create: (_) => FirebaseStorageRepository(),
        ),
        ChangeNotifierProvider(
          create: (context) => MarketplaceProvider(
            repository: context.read<FirebaseMarketplaceRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => MarketplaceAuthProvider(
            context.read<MarketplaceProvider>(),
            repository: context.read<FirebaseMarketplaceRepository>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return MaterialApp(
            title: 'Shop Wave',
            debugShowCheckedModeBanner: false,
            theme: MarketplaceTheme.light,
            locale: languageProvider.locale,
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MarketplaceShell(),
          );
        },
      ),
    );
  }
}
