import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../localization/marketplace_copy.dart';
import '../../models/marketplace_models.dart';
import '../../providers/marketplace_auth_provider.dart';
import '../../providers/marketplace_provider.dart';
import '../../widgets/marketplace_widgets.dart';

Future<bool> showMarketplaceAuthDialog(
  BuildContext context, {
  bool startWithRegistration = false,
  MarketplaceRole initialRole = MarketplaceRole.customer,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => MarketplaceAuthDialog(
      startWithRegistration: startWithRegistration,
      initialRole: initialRole,
    ),
  );
  return result == true;
}

class MarketplaceAuthDialog extends StatefulWidget {
  final bool startWithRegistration;
  final MarketplaceRole initialRole;

  const MarketplaceAuthDialog({
    super.key,
    this.startWithRegistration = false,
    this.initialRole = MarketplaceRole.customer,
  });

  @override
  State<MarketplaceAuthDialog> createState() => _MarketplaceAuthDialogState();
}

class _MarketplaceAuthDialogState extends State<MarketplaceAuthDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _storeName = TextEditingController();
  final _storeCity = TextEditingController(text: 'Aden');
  final _storeDescription = TextEditingController();

  late bool _registering;
  late MarketplaceRole _registerRole;
  String _categoryId = 'smartphones';
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _busy = false;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    _registering = widget.startWithRegistration;
    _registerRole = widget.initialRole == MarketplaceRole.seller
        ? MarketplaceRole.seller
        : MarketplaceRole.customer;
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _storeName.dispose();
    _storeCity.dispose();
    _storeDescription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<MarketplaceAuthProvider>();
    final market = context.read<MarketplaceProvider>();
    return AlertDialog(
      backgroundColor: Colors.white,
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(23, 21, 23, 8),
      contentPadding: const EdgeInsets.fromLTRB(23, 8, 23, 8),
      actionsPadding: const EdgeInsets.fromLTRB(18, 5, 18, 15),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4F2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _registering && _registerRole == MarketplaceRole.seller
                  ? Icons.storefront_outlined
                  : Icons.person_outline_rounded,
              color: marketplaceTeal,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _registering
                      ? marketText(context, 'Create your account', 'إنشاء حساب جديد')
                      : marketText(context, 'Welcome to Shop Wave', 'مرحباً بك في شوب ويف'),
                  style: const TextStyle(
                    color: marketplaceInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _registering
                      ? marketText(context, 'Join customers and independent stores.', 'انضم إلى العملاء والمتاجر المستقلة.')
                      : marketText(context, 'Sign in with your username or email.', 'سجّل الدخول باسم المستخدم أو البريد الإلكتروني.'),
                  style: const TextStyle(color: marketplaceMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 470,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_registering) ..._registrationFields(market),
              if (!_registering)
                TextFormField(
                  key: const ValueKey('auth-identifier'),
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: marketText(context, 'Username or email', 'اسم المستخدم أو البريد الإلكتروني'),
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                  ),
                  controller: _username,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? marketText(context, 'Enter your username or email.', 'أدخل اسم المستخدم أو البريد الإلكتروني.')
                      : null,
                ),
              if (_registering) const SizedBox(height: 11),
              TextFormField(
                key: const ValueKey('auth-password'),
                controller: _password,
                obscureText: _obscurePassword,
                textInputAction: _registering ? TextInputAction.next : TextInputAction.done,
                autofillHints: _registering
                    ? const [AutofillHints.newPassword]
                    : const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(auth),
                decoration: InputDecoration(
                  labelText: marketText(context, 'Password', 'كلمة المرور'),
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? marketText(context, 'Show password', 'إظهار كلمة المرور')
                        : marketText(context, 'Hide password', 'إخفاء كلمة المرور'),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: _registering
                    ? (value) => value == null || value.length < 8
                        ? marketText(context, 'Use at least 8 characters.', 'استخدم 8 أحرف على الأقل.')
                        : null
                    : null,
              ),
              if (_registering) ...[
                const SizedBox(height: 11),
                TextFormField(
                  controller: _confirmPassword,
                  obscureText: _obscureConfirmation,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: marketText(context, 'Confirm password', 'تأكيد كلمة المرور'),
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureConfirmation = !_obscureConfirmation),
                      icon: Icon(_obscureConfirmation ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (value) => value != _password.text
                      ? marketText(context, 'Passwords do not match.', 'كلمتا المرور غير متطابقتين.')
                      : null,
                  onFieldSubmitted: (_) => _submit(auth),
                ),
              ],
              if (_errorCode != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEFED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: marketplaceCoral, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorText(_errorCode!), style: const TextStyle(color: marketplaceCoral, fontSize: 11, height: 1.35))),
                    ],
                  ),
                ),
              ],
              if (!_registering) ...[
                const SizedBox(height: 11),
                Text(
                  marketText(context, 'Browsing is open to everyone. Sign in is required to place an order.', 'يمكن للجميع التصفح. يلزم تسجيل الدخول لإتمام الشراء.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: marketplaceMuted, fontSize: 10, height: 1.45),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(marketText(context, 'Cancel', 'إلغاء')),
        ),
        TextButton(
          onPressed: _busy ? null : () => setState(() {
            _registering = !_registering;
            _errorCode = null;
          }),
          child: Text(
            _registering
                ? marketText(context, 'I have an account', 'لدي حساب')
                : marketText(context, 'Create account', 'إنشاء حساب'),
          ),
        ),
        FilledButton.icon(
          onPressed: _busy || !auth.isInitialized ? null : () => _submit(auth),
          icon: _busy
              ? const SizedBox.square(dimension: 15, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_registering ? Icons.person_add_alt_1_rounded : Icons.login_rounded, size: 17),
          label: Text(
            _registering
                ? marketText(context, 'Register', 'تسجيل')
                : marketText(context, 'Sign in', 'دخول'),
          ),
        ),
      ],
    );
  }

  List<Widget> _registrationFields(MarketplaceProvider market) {
    return [
      SegmentedButton<MarketplaceRole>(
        segments: [
          ButtonSegment(
            value: MarketplaceRole.customer,
            icon: const Icon(Icons.person_outline_rounded),
            label: Text(marketText(context, 'Customer', 'عميل')),
          ),
          ButtonSegment(
            value: MarketplaceRole.seller,
            icon: const Icon(Icons.storefront_outlined),
            label: Text(marketText(context, 'Seller', 'بائع')),
          ),
        ],
        selected: {_registerRole},
        showSelectedIcon: false,
        onSelectionChanged: (selected) => setState(() {
          _registerRole = selected.first;
          _errorCode = null;
        }),
      ),
      const SizedBox(height: 13),
      TextFormField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.name],
        decoration: InputDecoration(
          labelText: marketText(context, 'Full name', 'الاسم الكامل'),
          prefixIcon: const Icon(Icons.badge_outlined),
        ),
        validator: (value) => value == null || value.trim().length < 2
            ? marketText(context, 'Enter your name.', 'أدخل الاسم الكامل.')
            : null,
      ),
      const SizedBox(height: 11),
      TextFormField(
        controller: _username,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: marketText(context, 'Username', 'اسم المستخدم'),
          helperText: marketText(context, '3–24 characters: letters, numbers, dot, dash or underscore.', 'من 3 إلى 24 حرفاً: أحرف وأرقام ونقطة أو شرطة.'),
          prefixIcon: const Icon(Icons.alternate_email_rounded),
        ),
        validator: (value) => value == null ||
                !RegExp(r'^[a-zA-Z0-9_.-]{3,24}$').hasMatch(value.trim()) ||
                value.trim().toLowerCase() == MarketplaceAuthProvider.adminUsername
            ? marketText(context, 'Choose a valid, available username.', 'اختر اسم مستخدم صالحاً وغير مستخدم.')
            : null,
      ),
      const SizedBox(height: 11),
      TextFormField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: InputDecoration(
          labelText: marketText(context, 'Email address', 'البريد الإلكتروني'),
          prefixIcon: const Icon(Icons.mail_outline_rounded),
        ),
        validator: (value) => value == null ||
                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(value.trim())
            ? marketText(context, 'Enter a valid email address.', 'أدخل بريداً إلكترونياً صحيحاً.')
            : null,
      ),
      const SizedBox(height: 11),
      TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        decoration: InputDecoration(
          labelText: marketText(context, 'Phone number (optional)', 'رقم الهاتف (اختياري)'),
          prefixIcon: const Icon(Icons.phone_outlined),
        ),
      ),
      if (_registerRole == MarketplaceRole.seller) ...[
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            marketText(context, 'Store details', 'بيانات المتجر'),
            style: const TextStyle(color: marketplaceInk, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        const SizedBox(height: 9),
        TextFormField(
          controller: _storeName,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: marketText(context, 'Store name', 'اسم المتجر'),
            prefixIcon: const Icon(Icons.store_mall_directory_outlined),
          ),
          validator: _registerRole == MarketplaceRole.seller
              ? (value) => value == null || value.trim().length < 2
                  ? marketText(context, 'Enter your store name.', 'أدخل اسم المتجر.')
                  : null
              : null,
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: _categoryId,
                isExpanded: true,
                decoration: InputDecoration(labelText: marketText(context, 'Category', 'الفئة')),
                items: market.categories
                    .map((category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(categoryTitle(context, category), overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _categoryId = value ?? 'home'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _storeCity,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: marketText(context, 'City', 'المدينة')),
                validator: (value) => value == null || value.trim().isEmpty
                    ? marketText(context, 'Enter a city.', 'أدخل المدينة.')
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        TextFormField(
          controller: _storeDescription,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: marketText(context, 'Store description (optional)', 'وصف المتجر (اختياري)'),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          marketText(context, 'Your store will be available for management immediately and listed after platform approval.', 'ستتمكن من إدارة متجرك فوراً، ويظهر للعملاء بعد موافقة إدارة المنصة.'),
          style: const TextStyle(color: marketplaceMuted, fontSize: 10, height: 1.4),
        ),
      ],
    ];
  }

  Future<void> _submit(MarketplaceAuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errorCode = null;
    });

    MarketplaceAuthResult result;
    if (_registering) {
      if (_registerRole == MarketplaceRole.seller) {
        result = await auth.registerSeller(
          displayName: _name.text,
          username: _username.text,
          email: _email.text,
          password: _password.text,
          phone: _phone.text,
          storeName: _storeName.text,
          storeCategoryId: _categoryId,
          storeCity: _storeCity.text,
          storeDescription: _storeDescription.text,
        );
      } else {
        result = await auth.registerCustomer(
          displayName: _name.text,
          username: _username.text,
          email: _email.text,
          password: _password.text,
          phone: _phone.text,
        );
      }
    } else {
      result = await auth.signIn(
        identifier: _username.text,
        password: _password.text,
      );
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _errorCode = result.errorCode;
    });
    if (result.isSuccess) Navigator.pop(context, true);
  }

  String _errorText(String code) {
    switch (code) {
      case 'invalid_credentials':
        return marketText(context, 'The username/email or password is incorrect.', 'اسم المستخدم أو البريد الإلكتروني أو كلمة المرور غير صحيحة.');
      case 'invalid_name':
        return marketText(context, 'Enter a valid full name.', 'أدخل اسماً صحيحاً.');
      case 'invalid_username':
        return marketText(context, 'Choose a username with 3–24 letters, numbers, dots or dashes.', 'اختر اسم مستخدم من 3 إلى 24 حرفاً أو رقماً أو نقطة أو شرطة.');
      case 'invalid_email':
        return marketText(context, 'Enter a valid, non-reserved email address.', 'أدخل بريداً إلكترونياً صالحاً وغير محجوز.');
      case 'weak_password':
        return marketText(context, 'Your password must contain at least 8 characters.', 'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.');
      case 'invalid_store':
        return marketText(context, 'Enter a valid store name.', 'أدخل اسم متجر صحيحاً.');
      case 'username_taken':
        return marketText(context, 'That username is already in use.', 'اسم المستخدم مستخدم بالفعل.');
      case 'email_taken':
        return marketText(context, 'An account already uses that email.', 'يوجد حساب مسجل بهذا البريد الإلكتروني.');
      case 'sign_in_required':
        return marketText(context, 'Sign in to apply for a seller account.', 'سجّل الدخول للتقديم كبائع.');
      default:
        return marketText(context, 'Something went wrong. Please try again.', 'حدث خطأ. حاول مرة أخرى.');
    }
  }
}
