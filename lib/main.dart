import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database/bikrito_database.dart';
import 'models/sale_record.dart';
import 'models/shop_profile.dart';
import 'models/shop_product.dart';
import 'screens/order_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/products_screen.dart';
import 'screens/sales_screen.dart';
import 'widgets/bikrito_bottom_navigation.dart';
import 'widgets/bikrito_logo.dart';

const _red = Color(0xFFD83B3B);
const _ink = Color(0xFF252525);
const _muted = Color(0xFF858585);
const _canvas = Color(0xFFFAF9F7);
const _businessTypeValues = [
  'clothing_boutiques',
  'homemade_food_cloud_kitchens',
  'organic_agro_products',
  'mobile_tech_accessories',
  'custom_gifts_crafts',
  'skincare_cosmetics',
  'baby_kids_items',
  'jewelry_ornaments',
  'other',
];

void main() => runApp(const BikritoApp());

class BikritoApp extends StatefulWidget {
  const BikritoApp({super.key});

  @override
  State<BikritoApp> createState() => _BikritoAppState();
}

class _BikritoAppState extends State<BikritoApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _homeKey = GlobalKey<_HomeScreenState>();
  ShopProfile? _profile;
  List<ShopProduct> _products = [];
  List<SaleRecord> _sales = [];
  bool _bangla = false;
  bool _loading = true;
  bool _authenticated = false;
  String? _startupError;

  String t(String en, String bn) => _bangla ? bn : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _startupError = null;
      });
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final db = BikritoDatabase.instance;
      var profile = await db.getProfile();
      var products = await db.getProducts();
      var sales = await db.getSales();

      // Bring forward data from the first app version, which used SharedPreferences.
      if (profile == null) {
        final legacyProfile = prefs.getString('shop_profile');
        if (legacyProfile != null) {
          profile = ShopProfile.fromJson(
            jsonDecode(legacyProfile) as Map<String, dynamic>,
          );
          await db.saveProfile(profile);
        }
      }
      if (products.isEmpty) {
        final legacyProducts = prefs.getString('shop_products');
        if (legacyProducts != null) {
          final items = (jsonDecode(legacyProducts) as List<dynamic>).map(
            (item) => ShopProduct.fromJson(item as Map<String, dynamic>),
          );
          for (final product in items) {
            await db.addProduct(product);
          }
          products = await db.getProducts();
        }
      }
      await prefs.remove('shop_profile');
      await prefs.remove('shop_products');
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _products = products;
        _sales = sales;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Bikrito startup failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _startupError = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile(ShopProfile profile) async {
    await BikritoDatabase.instance.saveProfile(profile);
    if (mounted) setState(() => _profile = profile);
  }

  Future<void> _addProduct(ShopProduct product) async {
    final id = await BikritoDatabase.instance.addProduct(product);
    if (mounted)
      setState(() => _products = [productWithId(product, id), ..._products]);
  }

  Future<void> _deleteProduct(int index) async {
    final product = _products[index];
    if (product.id != null)
      await BikritoDatabase.instance.deleteProduct(product.id!);
    if (mounted)
      setState(
        () => _products = List<ShopProduct>.from(_products)..removeAt(index),
      );
  }

  Future<void> _deleteProductById(int id) async {
    await BikritoDatabase.instance.deleteProduct(id);
    await _refreshProducts();
  }

  Future<List<ShopProduct>> _refreshProducts() async {
    final products = await BikritoDatabase.instance.getProducts();
    if (mounted) setState(() => _products = products);
    return products;
  }

  Future<SaleRecord> _recordSale(SaleRecord sale) async {
    final id = await BikritoDatabase.instance.createSale(sale);
    final saved = sale.withId(id);
    if (mounted) setState(() => _sales = [saved, ..._sales]);
    return saved;
  }

  Future<void> _openSalePage() async {
    final saleCounts = await BikritoDatabase.instance.getProductSaleCounts();
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => SalesScreen(
          products: _products,
          saleCounts: saleCounts,
          profile: _profile!,
          bangla: _bangla,
          t: t,
          onSave: _recordSale,
          onNavigate: _handleBottomNavigation,
        ),
      ),
    );
  }

  Future<void> _openOrderPage() async {
    final saleCounts = await BikritoDatabase.instance.getProductSaleCounts();
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => OrderScreen(
          products: _products,
          saleCounts: saleCounts,
          profile: _profile!,
          bangla: _bangla,
          t: t,
          onSave: _recordSale,
          onNavigate: _handleBottomNavigation,
        ),
      ),
    );
  }

  Future<void> _openReportsPage() async {
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => SalesReportsScreen(
          sales: _sales,
          profile: _profile!,
          bangla: _bangla,
          t: t,
          onNavigate: _handleBottomNavigation,
          onNewSale: _openSalePage,
        ),
      ),
    );
  }

  Future<void> _openOrdersPage() async {
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => OrdersScreen(
          orders: _sales.where((s) => s.paymentMethod == 'cod').toList(),
          profile: _profile!,
          bangla: _bangla,
          t: t,
          onNavigate: _handleBottomNavigation,
        ),
      ),
    );
  }

  Future<void> _openProductsPage() async {
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => ProductsScreen(
          products: _products,
          t: t,
          onNavigate: _handleBottomNavigation,
          onNewSale: _openSalePage,
          onAdd: _openProductForm,
          onDelete: _deleteProductById,
          onRefresh: _refreshProducts,
        ),
      ),
    );
  }

  void _handleBottomNavigation(int index) {
    final navigator = _navigatorKey.currentState!;
    _homeKey.currentState?.setSelectedTab(index);
    switch (index) {
      case 0:
        navigator.popUntil((route) => route.isFirst);
        _homeKey.currentState?.scrollToTop();
        break;
      case 1:
        navigator.popUntil((route) => route.isFirst);
        _openProductsPage();
        break;
      case 2:
        navigator.popUntil((route) => route.isFirst);
        _openReportsPage();
        break;
      case 3:
        navigator.popUntil((route) => route.isFirst);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _homeKey.currentState?.openDrawer();
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Bikrito',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _red,
          primary: _red,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: _canvas,
          foregroundColor: _ink,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _canvas,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFECEAE7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _red, width: 1.4),
          ),
        ),
      ),
      home: _loading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator(color: _red)),
            )
          : _startupError != null
          ? _StartupErrorScreen(error: _startupError!, onRetry: _load, t: t)
          : _profile == null
          ? SetupScreen(
              bangla: _bangla,
              t: t,
              onLanguage: () => setState(() => _bangla = !_bangla),
              onSave: _saveProfile,
            )
          : _profile!.userId.isEmpty || _profile!.pinHash.isEmpty
          ? SetupScreen(
              bangla: _bangla,
              t: t,
              onLanguage: () => setState(() => _bangla = !_bangla),
              onSave: _saveProfile,
              initial: _profile,
              requiredSetup: true,
            )
          : !_authenticated
          ? LoginScreen(
              profile: _profile!,
              bangla: _bangla,
              t: t,
              onLanguage: () => setState(() => _bangla = !_bangla),
              onLogin: (userId, pin) {
                final pinHash = sha256.convert(utf8.encode(pin)).toString();
                final valid =
                    userId.trim() == _profile!.userId &&
                    pinHash == _profile!.pinHash;
                if (valid) setState(() => _authenticated = true);
                return valid;
              },
            )
          : HomeScreen(
              key: _homeKey,
              profile: _profile!,
              products: _products,
              sales: _sales,
              bangla: _bangla,
              t: t,
              onLanguage: () => setState(() => _bangla = !_bangla),
              onAdd: _openProductForm,
              onDelete: _deleteProduct,
              onEditProfile: _editProfile,
              onLogout: () => setState(() => _authenticated = false),
              onNewSale: _openSalePage,
              onOrder: _openOrderPage,
              onReports: _openReportsPage,
              onOrders: _openOrdersPage,
              onNavigate: _handleBottomNavigation,
            ),
    );
  }

  Future<void> _openProductForm() async {
    final product = await _navigatorKey.currentState!.push<ShopProduct>(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          bangla: _bangla,
          t: t,
          onNavigate: _handleBottomNavigation,
          onNewSale: _openSalePage,
        ),
      ),
    );
    if (product != null) await _addProduct(product);
  }

  Future<void> _editProfile() async {
    final profile = await _navigatorKey.currentState!.push<ShopProfile>(
      MaterialPageRoute(
        builder: (_) => SetupScreen(
          bangla: _bangla,
          t: t,
          onSave: _saveProfile,
          initial: _profile,
        ),
      ),
    );
    if (profile != null) _saveProfile(profile);
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({
    required this.error,
    required this.onRetry,
    required this.t,
  });

  final String error;
  final VoidCallback onRetry;
  final String Function(String, String) t;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_rounded, color: _red, size: 48),
                const SizedBox(height: 16),
                Text(
                  t(
                    'Could not open Bikrito data',
                    'বিক্রিতোর তথ্য খোলা যায়নি',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'Please try again. Error: $error',
                    'আবার চেষ্টা করুন। ত্রুটি: $error',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(t('Try again', 'আবার চেষ্টা করুন')),
                  style: FilledButton.styleFrom(backgroundColor: _red),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.profile,
    required this.bangla,
    required this.t,
    required this.onLanguage,
    required this.onLogin,
  });

  final ShopProfile profile;
  final bool bangla;
  final String Function(String, String) t;
  final VoidCallback onLanguage;
  final bool Function(String userId, String pin) onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userId = TextEditingController();
  final _pin = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _userId.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final accepted = widget.onLogin(_userId.text, _pin.text);
    if (accepted) {
      _pin.clear();
    } else {
      setState(
        () => _error = widget.t(
          'User ID or PIN is incorrect.',
          'ইউজার আইডি অথবা পিন সঠিক নয়।',
        ),
      );
      _pin.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: widget.onLanguage,
            child: Text(
              widget.bangla ? 'English' : 'বাংলা',
              style: const TextStyle(color: _red, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFECEAE7)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A252525),
                      blurRadius: 28,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          BikritoLogo(size: 48, borderRadius: 15),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bikrito',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              Text(
                                t(
                                  'Your business, in your pocket',
                                  'আপনার ব্যবসা, আপনার হাতেই',
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Text(
                        t('Welcome back', 'আবার স্বাগতম'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t(
                          'Sign in to ${widget.profile.shop}',
                          '${widget.profile.shop}-এ প্রবেশ করুন',
                        ),
                        style: const TextStyle(fontSize: 15, color: _muted),
                      ),
                      const SizedBox(height: 30),
                      _FieldLabel(t('User ID', 'ইউজার আইডি')),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _userId,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: t(
                            'Enter your user ID',
                            'আপনার ইউজার আইডি লিখুন',
                          ),
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? t('Enter your user ID', 'আপনার ইউজার আইডি লিখুন')
                            : null,
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel(t('4-digit PIN', '৪ সংখ্যার পিন')),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _pin,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: '••••',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          counterText: '',
                        ),
                        validator: (value) =>
                            RegExp(r'^\d{4}$').hasMatch(value ?? '')
                            ? null
                            : t(
                                'Enter your 4-digit PIN',
                                'আপনার ৪ সংখ্যার পিন লিখুন',
                              ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: _red, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: _red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            t('Log in', 'লগ ইন'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          t(
                            'Your account stays on this device.',
                            'আপনার অ্যাকাউন্ট এই ডিভাইসেই থাকবে।',
                          ),
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.bangla,
    required this.t,
    required this.onSave,
    this.onLanguage,
    this.initial,
    this.requiredSetup = false,
  });
  final bool bangla;
  final String Function(String, String) t;
  final Future<void> Function(ShopProfile) onSave;
  final VoidCallback? onLanguage;
  final ShopProfile? initial;
  final bool requiredSetup;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initial?.email ?? '');
  late final _userId = TextEditingController(
    text: widget.initial?.userId ?? '',
  );
  final _pin = TextEditingController();
  late final _owner = TextEditingController(text: widget.initial?.owner ?? '');
  late final _shop = TextEditingController(text: widget.initial?.shop ?? '');
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  late String? _businessType = _initialBusinessType;
  late final _businessTypeOther = TextEditingController(
    text: widget.initial?.businessType == 'other'
        ? widget.initial?.businessTypeOther ?? ''
        : _businessType == 'other'
        ? widget.initial?.businessType ?? ''
        : widget.initial?.businessTypeOther ?? '',
  );
  late String? _logoPath = widget.initial?.logoPath;
  late String? _logoData = widget.initial?.logoData;

  String? get _initialBusinessType {
    final value = widget.initial?.businessType ?? '';
    if (value.isEmpty) return null;
    return _businessTypeValues.contains(value) ? value : 'other';
  }

  @override
  void dispose() {
    _email.dispose();
    _userId.dispose();
    _pin.dispose();
    _owner.dispose();
    _shop.dispose();
    _phone.dispose();
    _businessTypeOther.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (image == null) return;
      if (kIsWeb) {
        final encoded = base64Encode(await image.readAsBytes());
        if (mounted) setState(() => _logoData = encoded);
        return;
      }
      final documents = await getApplicationDocumentsDirectory();
      final logoDirectory = Directory(p.join(documents.path, 'shop_logo'));
      await logoDirectory.create(recursive: true);
      final destination = p.join(
        logoDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}${p.extension(image.path)}',
      );
      final saved = await File(image.path).copy(destination);
      if (mounted) setState(() => _logoPath = saved.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.t(
              'Could not add logo. Please try again.',
              'লোগো যোগ করা যায়নি। আবার চেষ্টা করুন।',
            ),
          ),
        ),
      );
    }
  }

  Widget _logoPreview() {
    if (_logoData != null && _logoData!.isNotEmpty) {
      return Image.memory(base64Decode(_logoData!), fit: BoxFit.cover);
    }
    if (_logoPath != null && _logoPath!.isNotEmpty) {
      return Image.file(File(_logoPath!), fit: BoxFit.cover);
    }
    return const ColoredBox(
      color: Color(0xFFFFEEEE),
      child: Icon(Icons.storefront_rounded, color: _red, size: 36),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Scaffold(
      appBar: AppBar(
        leading: widget.initial == null || widget.requiredSetup
            ? null
            : const BackButton(),
        actions: [
          if (widget.onLanguage != null)
            TextButton(
              onPressed: widget.onLanguage,
              child: Text(
                widget.bangla ? 'English' : 'বাংলা',
                style: const TextStyle(
                  color: _red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFECEAE7)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A252525),
                      blurRadius: 28,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          BikritoLogo(size: 48, borderRadius: 15),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bikrito',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              Text(
                                t('SHOP OWNER SETUP', 'দোকানের সেটআপ'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _muted,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Text(
                        widget.initial == null
                            ? t(
                                'Let’s set up your shop',
                                'আপনার দোকান সেট আপ করি',
                              )
                            : t('Shop details', 'দোকানের তথ্য'),
                        style: const TextStyle(
                          fontSize: 28,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t(
                          'A few details to make your bills yours.',
                          'আপনার বিল তৈরি করতে কয়েকটি তথ্য দিন।',
                        ),
                        style: const TextStyle(fontSize: 15, color: _muted),
                      ),
                      const SizedBox(height: 26),
                      Center(
                        child: GestureDetector(
                          onTap: _pickLogo,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 96,
                              height: 96,
                              color: Colors.white,
                              child: _logoPreview(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          t(
                            'Add shop logo (optional)',
                            'দোকানের লোগো যোগ করুন (ঐচ্ছিক)',
                          ),
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ),
                      const SizedBox(height: 26),
                      _FieldLabel(t('Email address', 'ইমেইল ঠিকানা')),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: 'you@example.com',
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(email)
                              ? null
                              : t(
                                  'Enter a valid email address',
                                  'সঠিক ইমেইল ঠিকানা লিখুন',
                                );
                        },
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel(t('User ID', 'ইউজার আইডি')),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _userId,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: t(
                            'Choose a user ID',
                            'একটি ইউজার আইডি দিন',
                          ),
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (value) {
                          final userId = value?.trim() ?? '';
                          return RegExp(r'^[a-zA-Z0-9_]{3,24}$')
                                  .hasMatch(userId)
                              ? null
                              : t(
                                  'Use 3–24 letters, numbers, or underscores',
                                  '৩–২৪টি অক্ষর, সংখ্যা বা আন্ডারস্কোর ব্যবহার করুন',
                                );
                        },
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel(t('4-digit PIN', '৪ সংখ্যার পিন')),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _pin,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        decoration: InputDecoration(
                          hintText: widget.initial == null
                              ? '••••'
                              : t(
                                  'Leave blank to keep current PIN',
                                  'বর্তমান পিন রাখতে ফাঁকা রাখুন',
                                ),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          counterText: '',
                        ),
                        validator: (value) {
                          final pin = value ?? '';
                          if (widget.initial != null &&
                              widget.initial!.pinHash.isNotEmpty &&
                              pin.isEmpty) {
                            return null;
                          }
                          return RegExp(r'^\d{4}$').hasMatch(pin)
                              ? null
                              : t(
                                  'PIN must be exactly 4 digits',
                                  'পিন অবশ্যই ৪ সংখ্যার হতে হবে',
                                );
                        },
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel(t('Owner name', 'মালিকের নাম')),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _owner,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: t('e.g. Rahim Ahmed', 'যেমন: রহিম আহমেদ'),
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? t('Please enter your name', 'আপনার নাম লিখুন')
                            : null,
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel(t('Shop name', 'দোকানের নাম')),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _shop,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: t('e.g. Rahim’s Store', 'যেমন: রহিম স্টোর'),
                          prefixIcon: const Icon(Icons.storefront_outlined),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? t('Please enter a shop name', 'দোকানের নাম লিখুন')
                            : null,
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel(t('Business type', 'ব্যবসার ধরন')),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _businessType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.store_mall_directory_outlined),
                        ),
                        hint: Text(
                          t('Select business type', 'ব্যবসার ধরন বাছুন'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'clothing_boutiques',
                            child: Text(
                              t('Clothing & Boutiques', 'পোশাক ও বুটিক'),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'homemade_food_cloud_kitchens',
                            child: Text(
                              t(
                                'Homemade Food & Cloud Kitchens',
                                'ঘরে তৈরি খাবার ও ক্লাউড কিচেন',
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'organic_agro_products',
                            child: Text(
                              t('Organic Agro Products', 'জৈব কৃষিপণ্য'),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'mobile_tech_accessories',
                            child: Text(
                              t(
                                'Mobile & Tech Accessories',
                                'মোবাইল ও প্রযুক্তি অ্যাক্সেসরিজ',
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'custom_gifts_crafts',
                            child: Text(
                              t(
                                'Custom Gifts & Crafts',
                                'কাস্টম উপহার ও হস্তশিল্প',
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'skincare_cosmetics',
                            child: Text(
                              t(
                                'Skincare & Cosmetics',
                                'ত্বকের যত্ন ও প্রসাধনী',
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'baby_kids_items',
                            child: Text(t('Baby & Kids Items', 'শিশুদের পণ্য')),
                          ),
                          DropdownMenuItem(
                            value: 'jewelry_ornaments',
                            child: Text(
                              t('Jewelry & Ornaments', 'গয়না ও অলংকার'),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text(t('Other', 'অন্যান্য')),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _businessType = value),
                      ),
                      if (_businessType == 'other') ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const ValueKey('business-type-other'),
                          controller: _businessTypeOther,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: t(
                              'Enter your business type',
                              'আপনার ব্যবসার ধরন লিখুন',
                            ),
                            prefixIcon: const Icon(Icons.edit_outlined),
                          ),
                          validator: (value) =>
                              _businessType != 'other' ||
                                  (value != null && value.trim().isNotEmpty)
                              ? null
                              : t(
                                  'Please specify your business type',
                                  'আপনার ব্যবসার ধরন লিখুন',
                                ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _FieldLabel(t('WhatsApp number', 'হোয়াটসঅ্যাপ নম্বর')),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '+880 1XXX-XXXXXX',
                          prefixIcon: const Icon(Icons.chat_outlined),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? t(
                                'Please enter a WhatsApp number',
                                'হোয়াটসঅ্যাপ নম্বর লিখুন',
                              )
                            : null,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            final profile = ShopProfile(
                              email: _email.text.trim(),
                              userId: _userId.text.trim(),
                              pinHash: _pin.text.isEmpty
                                  ? widget.initial?.pinHash ?? ''
                                  : sha256
                                        .convert(utf8.encode(_pin.text))
                                        .toString(),
                              owner: _owner.text.trim(),
                              shop: _shop.text.trim(),
                              phone: _phone.text.trim(),
                              businessType: _businessType ?? '',
                              businessTypeOther: _businessType == 'other'
                                  ? _businessTypeOther.text.trim()
                                  : '',
                              logoPath: _logoPath,
                              logoData: _logoData,
                            );
                            if (widget.initial == null ||
                                widget.requiredSetup) {
                              await widget.onSave(profile);
                            } else {
                              Navigator.pop(context, profile);
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            t(
                              widget.initial == null
                                  ? 'Create my shop'
                                  : widget.requiredSetup
                                  ? 'Finish account setup'
                                  : 'Save changes',
                              widget.initial == null
                                  ? 'দোকান তৈরি করুন'
                                  : widget.requiredSetup
                                  ? 'অ্যাকাউন্ট সেটআপ শেষ করুন'
                                  : 'পরিবর্তন সংরক্ষণ করুন',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          t(
                            'Your shop details stay on this phone.',
                            'আপনার দোকানের তথ্য এই ফোনেই থাকবে।',
                          ),
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.products,
    required this.sales,
    required this.bangla,
    required this.t,
    required this.onLanguage,
    required this.onAdd,
    required this.onDelete,
    required this.onEditProfile,
    required this.onLogout,
    required this.onNewSale,
    required this.onOrder,
    required this.onReports,
    required this.onOrders,
    required this.onNavigate,
  });
  final ShopProfile profile;
  final List<ShopProduct> products;
  final List<SaleRecord> sales;
  final bool bangla;
  final String Function(String, String) t;
  final VoidCallback onLanguage, onAdd, onEditProfile, onLogout;
  final VoidCallback onNewSale, onOrder, onReports, onOrders;
  final ValueChanged<int> onNavigate;
  final ValueChanged<int> onDelete;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTab = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() => _selectedTab = index);
    widget.onNavigate(index);
  }

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void setSelectedTab(int index) {
    if (mounted) setState(() => _selectedTab = index);
  }

  void openDrawer() {
    setSelectedTab(3);
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final products = widget.products;
    final sales = widget.sales;
    final bangla = widget.bangla;
    final t = widget.t;
    final onLanguage = widget.onLanguage;
    final onAdd = widget.onAdd;
    final onDelete = widget.onDelete;
    final onEditProfile = widget.onEditProfile;
    final onLogout = widget.onLogout;
    final onNewSale = widget.onNewSale;
    final onOrder = widget.onOrder;
    final onReports = widget.onReports;
    final onOrders = widget.onOrders;
    final now = DateTime.now();
    final todaySales = sales
        .where(
          (sale) =>
              sale.createdAt.year == now.year &&
              sale.createdAt.month == now.month &&
              sale.createdAt.day == now.day,
        )
        .fold<double>(0, (sum, sale) => sum + sale.total);
    final allSales = sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final remainingSales = sales
        .where((sale) => sale.paymentMethod == 'remaining')
        .fold<double>(0, (sum, sale) => sum + sale.total);
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                decoration: const BoxDecoration(color: _red),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BikritoLogo(size: 46, borderRadius: 14),
                    const SizedBox(height: 18),
                    Text(
                      profile.shop,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.owner}  ·  ${profile.phone}',
                      style: const TextStyle(
                        color: Color(0xFFFFE7E7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.home_rounded, color: _ink),
                title: Text(
                  t('Home', 'হোম'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined, color: _ink),
                title: Text(
                  t('Products', 'পণ্য'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate(1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.point_of_sale_rounded, color: _red),
                title: Text(
                  t('New sale', 'নতুন বিক্রি'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onNewSale();
                },
              ),
              ListTile(
                leading: const Icon(Icons.shopping_bag_outlined, color: _ink),
                title: Text(
                  t('E-Commerce Order', 'ই-কমার্স অর্ডার'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onOrder();
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: _ink),
                title: Text(t('Sales reports', 'বিক্রির রিপোর্ট')),
                onTap: () {
                  Navigator.pop(context);
                  onReports();
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined, color: _ink),
                title: Text(t('Orders', 'অর্ডার')),
                onTap: () {
                  Navigator.pop(context);
                  onOrders();
                },
              ),
              const Divider(indent: 18, endIndent: 18),
              ListTile(
                leading: const Icon(Icons.tune_rounded, color: _ink),
                title: Text(t('Shop details', 'দোকানের তথ্য')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  onEditProfile();
                },
              ),
              const Spacer(),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 8,
                ),
                leading: const Icon(Icons.logout_rounded, color: _red),
                title: Text(
                  t('Log out', 'লগ আউট'),
                  style: const TextStyle(
                    color: _red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onLogout();
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 15, 22, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFECEAE7)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      BikritoLogo(size: 40, borderRadius: 13),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Bikrito',
                              style: TextStyle(
                                fontSize: 19,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: _ink,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              t('SHOP MANAGER', 'দোকান ম্যানেজার'),
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w700,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: onLanguage,
                        style: TextButton.styleFrom(
                          foregroundColor: _red,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(40, 40),
                        ),
                        child: Text(
                          bangla ? 'EN' : 'বাংলা',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Builder(
                        builder: (context) => IconButton.filledTonal(
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          icon: const Icon(Icons.menu_rounded),
                          tooltip: t('Open menu', 'মেনু খুলুন'),
                          style: IconButton.styleFrom(
                            foregroundColor: _red,
                            backgroundColor: const Color(0xFFFFEEEE),
                            minimumSize: const Size(40, 40),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('WELCOME BACK', 'স্বাগতম'),
                        style: const TextStyle(
                          color: Color(0xFFFFDADA),
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        profile.shop,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t('Owner', 'মালিক')}: ${profile.owner}  ·  ${profile.phone}',
                        style: const TextStyle(
                          color: Color(0xFFFFE9E9),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: t('Today sales', 'আজকের বিক্রি'),
                              value: '৳${_money(todaySales)}',
                              icon: Icons.trending_up_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              label: t('Mode', 'মোড'),
                              value: t('Offline', 'অফলাইন'),
                              icon: Icons.wifi_off_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: const Color(0xFFECEAE7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t('Business overview', 'ব্যবসার সারসংক্ষেপ'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                          ),
                          Text(
                            '${sales.length} ${t('sales', 'টি বিক্রি')}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 9,
                        crossAxisSpacing: 9,
                        childAspectRatio: 2.35,
                        children: [
                          _OverviewMetric(
                            label: t('All-time sales', 'সর্বমোট বিক্রি'),
                            value: '৳${_money(allSales)}',
                            icon: Icons.payments_outlined,
                          ),
                          _OverviewMetric(
                            label: t('Remaining', 'বাকি'),
                            value: '৳${_money(remainingSales)}',
                            icon: Icons.hourglass_bottom_rounded,
                            highlight: true,
                          ),
                          _OverviewMetric(
                            label: t('Products', 'পণ্য'),
                            value: '${products.length}',
                            icon: Icons.inventory_2_outlined,
                          ),
                          _OverviewMetric(
                            label: t('Recorded sales', 'সংরক্ষিত বিক্রি'),
                            value: '${sales.length}',
                            icon: Icons.receipt_long_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              sliver: SliverToBoxAdapter(
                child: InkWell(
                  onTap: onOrder,
                  borderRadius: BorderRadius.circular(19),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEEE),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: const Color(0xFFF3D5D5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _red,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('E-Commerce Order', 'ই-কমার্স অর্ডার'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                t(
                                  'Record COD orders with delivery charge.',
                                  'COD অর্ডার ডেলিারি চার্জসহ বুক করুন।',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: _red,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onNewSale,
                    icon: const Icon(Icons.point_of_sale_rounded),
                    label: Text(
                      t('Create a sale', 'বিক্রি তৈরি করুন'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('Your products', 'আপনার পণ্য'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t(
                              'Keep your prices close at hand.',
                              'আপনার পণ্যের দাম হাতের কাছে রাখুন।',
                            ),
                            style: const TextStyle(color: _muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      onPressed: onAdd,
                      style: IconButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      tooltip: t('Add product', 'পণ্য যোগ করুন'),
                    ),
                  ],
                ),
              ),
            ),
            if (products.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 34,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEFEDEB)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEEEE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: _red,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t(
                            'Your shelf is waiting',
                            'আপনার পণ্যের তালিকা তৈরি করুন',
                          ),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            'Add your first product to get started.',
                            'শুরু করতে প্রথম পণ্যটি যোগ করুন।',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: _muted),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: onAdd,
                          icon: const Icon(Icons.add_rounded, size: 19),
                          label: Text(t('Add a product', 'পণ্য যোগ করুন')),
                          style: FilledButton.styleFrom(
                            backgroundColor: _red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 19,
                              vertical: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                sliver: SliverList.separated(
                  itemCount: products.length > 4 ? 4 : products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: const Color(0xFFEFEDEB)),
                      ),
                      child: Row(
                        children: [
                          _ProductImage(
                            path: product.imagePath,
                            imageData: product.imageData,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '৳${_money(product.price)}',
                                  style: const TextStyle(
                                    color: _red,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              color: _muted,
                            ),
                            onSelected: (value) {
                              if (value == 'delete') onDelete(index);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(t('Remove product', 'পণ্য সরান')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (products.length > 4)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                  sliver: SliverToBoxAdapter(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onNavigate(1),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(t('View all products', 'সব পণ্য দেখুন')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _red,
                        side: const BorderSide(color: _red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SliverPadding(padding: EdgeInsets.only(bottom: 28)),
            ],
            if (sales.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t('Recent sales', 'সাম্প্রতিক বিক্রি'),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onReports,
                        child: Text(t('View all', 'সব দেখুন')),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                sliver: SliverList.separated(
                  itemCount: sales.length < 3 ? sales.length : 3,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    final itemCount = sale.items.fold<int>(
                      0,
                      (sum, item) => sum + item.quantity,
                    );
                    return Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFECEAE7)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEEEE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: _red,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t('Sale', 'বিক্রি')} #${sale.id ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_homePaymentLabel(sale.paymentMethod, t)} · $itemCount ${t('items', 'টি পণ্য')}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '৳${_money(sale.total)}',
                            style: const TextStyle(
                              color: _red,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Text(
                    t(
                      'Made for your everyday business.',
                      'আপনার প্রতিদিনের ব্যবসার জন্য।',
                    ),
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BikritoBottomBar(
        selectedIndex: _selectedTab,
        t: t,
        onNavigate: _selectTab,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: BikritoSaleButton(t: t, onPressed: onNewSale),
    );
  }
}

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    super.key,
    required this.bangla,
    required this.t,
    required this.onNavigate,
    required this.onNewSale,
  });
  final bool bangla;
  final String Function(String, String) t;
  final ValueChanged<int> onNavigate;
  final VoidCallback onNewSale;
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  String? _imagePath;
  String? _imageData;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (image == null) return;
      if (kIsWeb) {
        final encodedImage = base64Encode(await image.readAsBytes());
        if (mounted) setState(() => _imageData = encodedImage);
        return;
      }
      final documents = await getApplicationDocumentsDirectory();
      final imageDirectory = Directory(
        p.join(documents.path, 'product_images'),
      );
      await imageDirectory.create(recursive: true);
      final destination = p.join(
        imageDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}${p.extension(image.path)}',
      );
      final savedImage = await File(image.path).copy(destination);
      if (mounted) setState(() => _imagePath = savedImage.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.t(
              'Could not add photo. Please try again.',
              'ছবি যোগ করা যায়নি। আবার চেষ্টা করুন।',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('Add product', 'পণ্য যোগ করুন'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      bottomNavigationBar: BikritoBottomBar(
        selectedIndex: 1,
        t: t,
        onNavigate: widget.onNavigate,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: BikritoSaleButton(
        t: t,
        onPressed: widget.onNewSale,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            children: [
              Text(
                t('Product details', 'পণ্যের তথ্য'),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                t(
                  'Add the name and price. A photo is optional.',
                  'পণ্যের নাম ও দাম লিখুন। ছবি ঐচ্ছিক।',
                ),
                style: const TextStyle(color: _muted, fontSize: 14),
              ),
              const SizedBox(height: 26),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 124,
                    height: 124,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE9E6E3)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _imageData != null
                        ? Image.memory(
                            base64Decode(_imageData!),
                            fit: BoxFit.cover,
                            width: 124,
                            height: 124,
                          )
                        : _imagePath == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFEEEE),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_a_photo_outlined,
                                  color: _red,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t('Add photo', 'ছবি যোগ করুন'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Image.file(
                            File(_imagePath!),
                            fit: BoxFit.cover,
                            width: 124,
                            height: 124,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _FieldLabel(t('Product name', 'পণ্যের নাম')),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: t('e.g. Cotton T-shirt', 'যেমন: সুতি টি-শার্ট'),
                  prefixIcon: const Icon(Icons.sell_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? t('Enter a product name', 'পণ্যের নাম লিখুন')
                    : null,
              ),
              const SizedBox(height: 19),
              _FieldLabel(t('Selling price', 'বিক্রয় মূল্য')),
              const SizedBox(height: 8),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '৳',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                ),
                validator: (v) {
                  final price = double.tryParse((v ?? '').trim());
                  return price == null || price <= 0
                      ? t('Enter a valid price', 'সঠিক মূল্য লিখুন')
                      : null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    Navigator.pop(
                      context,
                      ShopProduct(
                        name: _name.text.trim(),
                        price: double.parse(_price.text.trim()),
                        imagePath: _imagePath,
                        imageData: _imageData,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    t('Save product', 'পণ্য সংরক্ষণ করুন'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: _ink,
    ),
  );
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: highlight ? const Color(0xFFFFEEEE) : _canvas,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        Icon(icon, size: 17, color: _red),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0x25FFFFFF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.white),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFFFFE5E5), fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.path, this.imageData});
  final String? path;
  final String? imageData;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: 58,
      height: 58,
      child: imageData != null
          ? Image.memory(
              base64Decode(imageData!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : path != null
          ? Image.file(
              File(path!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    ),
  );
  Widget _placeholder() => Container(
    color: const Color(0xFFFFEEEE),
    child: const Icon(Icons.inventory_2_outlined, color: _red, size: 23),
  );
}

String _money(double price) => price == price.roundToDouble()
    ? price.toStringAsFixed(0)
    : price.toStringAsFixed(2);

String _homePaymentLabel(String method, String Function(String, String) t) =>
    switch (method) {
      'bkash' => 'bKash',
      'nagad' => 'Nagad',
      'bank' => t('Bank', 'ব্যাংক'),
      'remaining' => t('Remaining', 'বাকি'),
      _ => t('Cash', 'নগদ'),
    };
