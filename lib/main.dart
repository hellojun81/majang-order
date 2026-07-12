import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }
  runApp(const MajangOrderApp());
}

class Product {
  Product(this.name, this.detail, this.unit, this.price, this.icon, {this.isActive = true});
  final String name;
  final String detail;
  final String unit;
  final int price;
  final IconData icon;
  bool isActive;

  Map<String, Object> toJson() => {
        'name': name,
        'detail': detail,
        'unit': unit,
        'price': price,
        'isActive': isActive,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        json['name'] as String,
        json['detail'] as String,
        json['unit'] as String,
        json['price'] as int,
        Icons.inventory_2_outlined,
        isActive: json['isActive'] as bool? ?? true,
      );
}

class CartLine {
  CartLine(this.product, {this.quantity = 1});
  final Product product;
  int quantity;

  Map<String, Object> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
      };

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        Product.fromJson(json['product'] as Map<String, dynamic>),
        quantity: json['quantity'] as int,
      );
}

class OperationSettings {
  bool requireStoreApproval = true;
  bool confirmActualWeight = true;
  bool requireCustomerConfirmation = false;
  bool useStoreSpecificPricing = false;
  bool allowBackorder = false;

  OperationSettings snapshot() => OperationSettings()
    ..requireStoreApproval = requireStoreApproval
    ..confirmActualWeight = confirmActualWeight
    ..requireCustomerConfirmation = requireCustomerConfirmation
    ..useStoreSpecificPricing = useStoreSpecificPricing
    ..allowBackorder = allowBackorder;

  Map<String, Object> toJson() => {
        'requireStoreApproval': requireStoreApproval,
        'confirmActualWeight': confirmActualWeight,
        'requireCustomerConfirmation': requireCustomerConfirmation,
        'useStoreSpecificPricing': useStoreSpecificPricing,
        'allowBackorder': allowBackorder,
      };

  void restore(Map<String, dynamic> json) {
    requireStoreApproval = json['requireStoreApproval'] as bool? ?? true;
    confirmActualWeight = json['confirmActualWeight'] as bool? ?? true;
    requireCustomerConfirmation = json['requireCustomerConfirmation'] as bool? ?? false;
    useStoreSpecificPricing = json['useStoreSpecificPricing'] as bool? ?? false;
    allowBackorder = json['allowBackorder'] as bool? ?? false;
  }
}

class DemoOrder {
  DemoOrder(
    this.number,
    this.lines,
    this.estimatedTotal,
    this.settings, {
    required this.deliveryDate,
    required this.processingRequest,
  });
  final String number;
  final List<CartLine> lines;
  final int estimatedTotal;
  final OperationSettings settings;
  final DateTime deliveryDate;
  final String processingRequest;
  OrderStage stage = OrderStage.pending;
  int? finalTotal;

  Map<String, Object?> toJson() => {
        'number': number,
        'lines': lines.map((line) => line.toJson()).toList(),
        'estimatedTotal': estimatedTotal,
        'settings': settings.toJson(),
        'deliveryDate': deliveryDate.toIso8601String(),
        'processingRequest': processingRequest,
        'stage': stage.name,
        'finalTotal': finalTotal,
      };

  factory DemoOrder.fromJson(Map<String, dynamic> json) {
    final restoredSettings = OperationSettings()..restore(json['settings'] as Map<String, dynamic>);
    return DemoOrder(
      json['number'] as String,
      (json['lines'] as List<dynamic>)
          .map((line) => CartLine.fromJson(line as Map<String, dynamic>))
          .toList(),
      json['estimatedTotal'] as int,
      restoredSettings,
      deliveryDate: DateTime.parse(json['deliveryDate'] as String),
      processingRequest: json['processingRequest'] as String? ?? '',
    )
      ..stage = OrderStage.values.firstWhere(
        (value) => value.name == json['stage'],
        orElse: () => OrderStage.pending,
      )
      ..finalTotal = json['finalTotal'] as int?;
  }
}

enum OrderStage { pending, weighing, customerConfirmation, preparing, rejected }

class AppStore extends ChangeNotifier {
  AppStore() {
    _loadProducts();
    _loadOrders();
    _loadSettings();
    _loadRetailerApproval();
  }

  static const _productsKey = 'majang_order_products_v1';
  static const _ordersKey = 'majang_order_orders_v1';
  static const _settingsKey = 'majang_order_settings_v1';
  static const _retailerApprovalKey = 'majang_order_retailer_approval_v1';
  final settings = OperationSettings();
  final List<Product> products = initialProducts
      .map((product) => Product(product.name, product.detail, product.unit, product.price, product.icon))
      .toList();
  final List<CartLine> cart = [];
  final List<DemoOrder> orders = [];
  DateTime requestedDeliveryDate = DateTime.now().add(const Duration(days: 1));
  String processingRequest = '';
  UserRole? signedInRole;
  RetailerApprovalStatus retailerApprovalStatus = RetailerApprovalStatus.pending;

  bool get retailerCanOrder =>
      !settings.requireStoreApproval || retailerApprovalStatus == RetailerApprovalStatus.approved;

  Future<void> _loadProducts() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_productsKey);
    if (saved == null) return;
    try {
      final decoded = jsonDecode(saved) as List<dynamic>;
      products
        ..clear()
        ..addAll(decoded.map((item) => Product.fromJson(item as Map<String, dynamic>)));
      notifyListeners();
    } on FormatException {
      // 손상된 로컬 데이터는 기본 상품 목록으로 안전하게 대체합니다.
    }
  }

  Future<void> _saveProducts() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _productsKey,
      jsonEncode(products.map((product) => product.toJson()).toList()),
    );
  }

  Future<void> _loadOrders() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_ordersKey);
    if (saved == null) return;
    try {
      final decoded = jsonDecode(saved) as List<dynamic>;
      orders
        ..clear()
        ..addAll(decoded.map((item) => DemoOrder.fromJson(item as Map<String, dynamic>)));
      notifyListeners();
    } on FormatException {
      // 손상된 발주 데이터는 표시하지 않습니다.
    }
  }

  Future<void> _saveOrders() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _ordersKey,
      jsonEncode(orders.map((order) => order.toJson()).toList()),
    );
  }

  Future<void> _loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_settingsKey);
    if (saved == null) return;
    try {
      settings.restore(jsonDecode(saved) as Map<String, dynamic>);
      notifyListeners();
    } on FormatException {
      // 손상된 설정은 기본 운영 설정으로 대체합니다.
    }
  }

  Future<void> _saveSettings() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> _loadRetailerApproval() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_retailerApprovalKey);
    retailerApprovalStatus = RetailerApprovalStatus.values.firstWhere(
      (status) => status.name == saved,
      orElse: () => RetailerApprovalStatus.pending,
    );
    notifyListeners();
  }

  Future<void> _saveRetailerApproval() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_retailerApprovalKey, retailerApprovalStatus.name);
  }

  void signIn(UserRole role) {
    signedInRole = role;
    notifyListeners();
  }

  void approveDemoRetailer() {
    retailerApprovalStatus = RetailerApprovalStatus.approved;
    _saveRetailerApproval();
    notifyListeners();
  }

  void rejectDemoRetailer() {
    retailerApprovalStatus = RetailerApprovalStatus.rejected;
    _saveRetailerApproval();
    notifyListeners();
  }

  void resetDemoRetailerApproval() {
    retailerApprovalStatus = RetailerApprovalStatus.pending;
    _saveRetailerApproval();
    notifyListeners();
  }

  void signOut() {
    signedInRole = null;
    notifyListeners();
  }

  void add(Product product) {
    final index = cart.indexWhere((line) => line.product.name == product.name);
    if (index < 0) {
      cart.add(CartLine(product));
    } else {
      cart[index].quantity++;
    }
    notifyListeners();
  }

  void addProduct({
    required String name,
    required String detail,
    required String unit,
    required int price,
  }) {
    products.insert(0, Product(name, detail, unit, price, Icons.inventory_2_outlined));
    _saveProducts();
    notifyListeners();
  }

  void toggleProduct(Product product, bool isActive) {
    product.isActive = isActive;
    _saveProducts();
    notifyListeners();
  }

  void changeQuantity(CartLine line, int delta) {
    line.quantity += delta;
    if (line.quantity <= 0) cart.remove(line);
    notifyListeners();
  }

  int get cartTotal => cart.fold(
        0,
        (total, line) => total + line.product.price * line.quantity,
      );

  void setDeliveryDate(DateTime value) {
    requestedDeliveryDate = value;
    notifyListeners();
  }

  void setProcessingRequest(String value) {
    processingRequest = value;
  }

  void placeOrder() {
    if (cart.isEmpty) return;
    orders.insert(
      0,
      DemoOrder(
        'MO-${1001 + orders.length}',
        cart.map((line) => CartLine(line.product, quantity: line.quantity)).toList(),
        cartTotal,
        settings.snapshot(),
        deliveryDate: requestedDeliveryDate,
        processingRequest: processingRequest.trim(),
      ),
    );
    cart.clear();
    requestedDeliveryDate = DateTime.now().add(const Duration(days: 1));
    processingRequest = '';
    _saveOrders();
    notifyListeners();
  }

  void acceptOrder(DemoOrder order) {
    order.stage = order.settings.confirmActualWeight ? OrderStage.weighing : OrderStage.preparing;
    if (!order.settings.confirmActualWeight) order.finalTotal = order.estimatedTotal;
    _saveOrders();
    notifyListeners();
  }

  void rejectOrder(DemoOrder order) {
    order.stage = OrderStage.rejected;
    _saveOrders();
    notifyListeners();
  }

  void confirmFinalAmount(DemoOrder order, int amount) {
    order.finalTotal = amount;
    order.stage = order.settings.requireCustomerConfirmation
        ? OrderStage.customerConfirmation
        : OrderStage.preparing;
    _saveOrders();
    notifyListeners();
  }

  void confirmOrderAsCustomer(DemoOrder order) {
    order.stage = OrderStage.preparing;
    _saveOrders();
    notifyListeners();
  }

  void updateSettings(void Function(OperationSettings value) update) {
    update(settings);
    if (!settings.confirmActualWeight) {
      settings.requireCustomerConfirmation = false;
    }
    _saveSettings();
    notifyListeners();
  }
}

enum UserRole { retailer, admin }

enum RetailerApprovalStatus { pending, approved, rejected }

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({required AppStore store, required super.child, super.key})
      : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

class MajangOrderApp extends StatefulWidget {
  const MajangOrderApp({super.key});

  @override
  State<MajangOrderApp> createState() => _MajangOrderAppState();
}

class _MajangOrderAppState extends State<MajangOrderApp> {
  final store = AppStore();

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF8E2B25);
    return StoreScope(
      store: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '마장오더',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
          scaffoldBackgroundColor: const Color(0xFFF8F5F1),
          useMaterial3: true,
          cardTheme: const CardThemeData(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.signedInRole == null) return const LoginPage();
    if (store.signedInRole == UserRole.retailer && !store.retailerCanOrder) {
      return const ApprovalWaitingPage();
    }
    return const MainShell();
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E2B25),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.storefront, color: Colors.white, size: 42),
                  ),
                  const SizedBox(height: 24),
                  const Text('마장오더', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('거래처와 도매점을 연결하는 간편 발주 서비스', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 34),
                  TextField(
                    decoration: InputDecoration(
                      labelText: '휴대폰 번호',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      prefixIcon: const Icon(Icons.lock_outline),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => store.signIn(UserRole.retailer),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('소매점 데모로 로그인'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => store.signIn(UserRole.admin),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('도매점 관리자 데모'),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppConfig.hasSupabase
                        ? 'Supabase 연결됨 · 서버 데이터 저장소 전환 준비 상태'
                        : '로컬 데모 모드 · Supabase 설정값을 넣으면 서버 연결이 활성화됩니다.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ApprovalWaitingPage extends StatelessWidget {
  const ApprovalWaitingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final isRejected = store.retailerApprovalStatus == RetailerApprovalStatus.rejected;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isRejected ? Icons.block_outlined : Icons.hourglass_top_rounded,
                    size: 72,
                    color: const Color(0xFF8E2B25),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    isRejected ? '거래처 승인이 보류되었습니다' : '거래처 승인 대기 중',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isRejected
                        ? '사업자 정보를 확인한 뒤 도매점에 문의해 주세요.'
                        : '도매점 확인이 끝나면 상품 조회와 발주를 시작할 수 있습니다.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextButton(onPressed: store.signOut, child: const Text('다른 계정으로 로그인')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = StoreScope.of(context).signedInRole == UserRole.admin;
    final pages = isAdmin
        ? const [AdminDashboardPage(), OrdersPage(), AdminPage(), AccountPage()]
        : const [ProductsPage(), CartPage(), OrdersPage(), AccountPage()];
    final destinations = isAdmin
        ? const [
            NavigationDestination(icon: Icon(Icons.dashboard), label: '현황'),
            NavigationDestination(icon: Icon(Icons.receipt_long), label: '발주관리'),
            NavigationDestination(icon: Icon(Icons.settings), label: '운영설정'),
            NavigationDestination(icon: Icon(Icons.person), label: '내 정보'),
          ]
        : const [
            NavigationDestination(icon: Icon(Icons.storefront), label: '상품'),
            NavigationDestination(icon: Icon(Icons.shopping_cart), label: '장바구니'),
            NavigationDestination(icon: Icon(Icons.receipt_long), label: '발주내역'),
            NavigationDestination(icon: Icon(Icons.person), label: '내 정보'),
          ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: destinations,
      ),
    );
  }
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('오늘의 발주 현황', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('마장오더 도매점 관리자', style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _SummaryCard(label: '신규 발주', value: '${store.orders.length}', icon: Icons.notifications_active)),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: '승인 대기',
                value: store.retailerApprovalStatus == RetailerApprovalStatus.pending ? '1' : '0',
                icon: Icons.store_mall_directory,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(child: _SummaryCard(label: '상품 준비', value: '0', icon: Icons.inventory_2)),
            SizedBox(width: 12),
            Expanded(child: _SummaryCard(label: '오늘 출고', value: '0', icon: Icons.local_shipping)),
          ],
        ),
        const SizedBox(height: 22),
        const Text('빠른 관리', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.store_outlined),
                title: Text('우리정육점'),
                subtitle: Text('사업자번호 123-45-67890 · 신규 거래처'),
              ),
              if (store.retailerApprovalStatus == RetailerApprovalStatus.pending)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: store.rejectDemoRetailer,
                          child: const Text('승인 보류'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: store.approveDemoRetailer,
                          child: const Text('거래처 승인'),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListTile(
                  leading: Icon(
                    store.retailerApprovalStatus == RetailerApprovalStatus.approved
                        ? Icons.check_circle_outline
                        : Icons.block_outlined,
                  ),
                  title: Text(
                    store.retailerApprovalStatus == RetailerApprovalStatus.approved ? '승인 완료' : '승인 보류',
                  ),
                  trailing: TextButton(
                    onPressed: store.resetDemoRetailerApproval,
                    child: const Text('재심사'),
                  ),
                ),
              const Divider(height: 1),
              const ListTile(leading: Icon(Icons.add_box_outlined), title: Text('상품 등록 및 단가 관리'), trailing: Icon(Icons.chevron_right)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF8E2B25)),
              const SizedBox(height: 16),
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              Text(label),
            ],
          ),
        ),
      );
}

final initialProducts = [
  Product('한우 등심 1++', '국내산 · 냉장 · 구이용', 'kg', 89500, Icons.set_meal),
  Product('한우 국거리', '국내산 · 냉장 · 정육', 'kg', 36500, Icons.restaurant),
  Product('한돈 삼겹살', '국내산 · 냉장 · 원육', 'kg', 21800, Icons.lunch_dining),
  Product('미국산 갈비살', '미국산 · 냉장 · 초이스', 'kg', 27900, Icons.kebab_dining),
];

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('마장오더', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('좋은 고기를 빠르게 발주하세요', style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 20),
        TextField(
          decoration: InputDecoration(
            hintText: '품목, 부위, 원산지 검색',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text('오늘의 상품', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...store.products.where((product) => product.isActive).map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E2DE),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(product.icon, color: const Color(0xFF8E2B25), size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(product.detail, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text('${money(product.price)}원 / ${product.unit}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () {
                        store.add(product);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${product.name}을 장바구니에 담았습니다.')),
                        );
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  Future<void> _selectDeliveryDate(BuildContext context, AppStore store) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: store.requestedDeliveryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: '배송 희망일 선택',
    );
    if (selected != null) store.setDeliveryDate(selected);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('장바구니', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Expanded(
            child: store.cart.isEmpty
                ? const Center(child: Text('담긴 상품이 없습니다.'))
                : ListView.separated(
                    itemCount: store.cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final line = store.cart[index];
                      return Card(
                        child: ListTile(
                          title: Text(line.product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${money(line.product.price * line.quantity)}원'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(onPressed: () => store.changeQuantity(line, -1), icon: const Icon(Icons.remove_circle_outline)),
                              Text('${line.quantity} ${line.product.unit}'),
                              IconButton(onPressed: () => store.changeQuantity(line, 1), icon: const Icon(Icons.add_circle_outline)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('배송 희망일'),
                    subtitle: Text(dateText(store.requestedDeliveryDate)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectDeliveryDate(context, store),
                  ),
                  TextField(
                    minLines: 2,
                    maxLines: 3,
                    onChanged: store.setProcessingRequest,
                    decoration: const InputDecoration(
                      labelText: '가공·포장 요청사항',
                      hintText: '예: 15mm 절단, 지방 제거, 1kg씩 진공포장',
                      prefixIcon: Icon(Icons.content_cut),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('예상 합계'),
                    Text('${money(store.cartTotal)}원', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ]),
                  if (store.settings.confirmActualWeight) ...[
                    const SizedBox(height: 8),
                    const Text('실중량 반영 후 도매점에서 최종금액을 확정합니다.', style: TextStyle(fontSize: 12)),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: store.cart.isEmpty
                          ? null
                          : () {
                              store.placeOrder();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('발주가 접수되었습니다.')));
                            },
                      child: const Text('발주하기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  Future<void> _showFinalAmountDialog(
    BuildContext context,
    AppStore store,
    DemoOrder order,
  ) async {
    final controller = TextEditingController(text: order.estimatedTotal.toString());
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('최종금액 확정'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: '실중량 반영 최종금액', suffixText: '원'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.replaceAll(',', ''));
              if (value != null && value > 0) Navigator.pop(context, value);
            },
            child: const Text('확정'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount != null) store.confirmFinalAmount(order, amount);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final isAdmin = store.signedInRole == UserRole.admin;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(isAdmin ? '발주관리' : '발주내역', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        if (isAdmin) ...[
          const SizedBox(height: 6),
          Text('접수부터 최종금액 확정까지 처리하세요.', style: TextStyle(color: Colors.grey.shade700)),
        ],
        const SizedBox(height: 18),
        if (store.orders.isEmpty)
          const SizedBox(height: 220, child: Center(child: Text('아직 발주내역이 없습니다.'))),
        ...store.orders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(order.number, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Chip(label: Text(orderStageLabel(order.stage))),
                    ]),
                    Text(order.lines.map((line) => '${line.product.name} ${line.quantity}${line.product.unit}').join(' · ')),
                    const SizedBox(height: 10),
                    Text('예상금액 ${money(order.estimatedTotal)}원'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text('배송 희망일 ${dateText(order.deliveryDate)}'),
                      ],
                    ),
                    if (order.processingRequest.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F0EC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('요청: ${order.processingRequest}'),
                      ),
                    ],
                    if (order.finalTotal != null)
                      Text('최종금액 ${money(order.finalTotal!)}원', style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (isAdmin && order.stage == OrderStage.pending) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: () => store.rejectOrder(order), child: const Text('거절'))),
                          const SizedBox(width: 8),
                          Expanded(child: FilledButton(onPressed: () => store.acceptOrder(order), child: const Text('발주 접수'))),
                        ],
                      ),
                    ],
                    if (isAdmin && order.stage == OrderStage.weighing) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _showFinalAmountDialog(context, store, order),
                          icon: const Icon(Icons.scale_outlined),
                          label: const Text('실중량·최종금액 입력'),
                        ),
                      ),
                    ],
                    if (!isAdmin && order.stage == OrderStage.customerConfirmation) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => store.confirmOrderAsCustomer(order),
                          child: const Text('최종금액 확인'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String orderStageLabel(OrderStage stage) => switch (stage) {
      OrderStage.pending => '신규 발주',
      OrderStage.weighing => '실중량 입력 대기',
      OrderStage.customerConfirmation => '고객 확인 대기',
      OrderStage.preparing => '상품 준비 중',
      OrderStage.rejected => '발주 거절',
    };

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  Future<void> _showAddProductDialog(BuildContext context, AppStore store) async {
    final nameController = TextEditingController();
    final detailController = TextEditingController(text: '국내산 · 냉장');
    final priceController = TextEditingController();
    var unit = 'kg';
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('새 상품 등록'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(labelText: '상품명')),
                const SizedBox(height: 10),
                TextField(controller: detailController, decoration: const InputDecoration(labelText: '원산지·보관·등급')),
                const SizedBox(height: 10),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '판매 단가', suffixText: '원'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: unit,
                  decoration: const InputDecoration(labelText: '주문 단위'),
                  items: const [
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                    DropdownMenuItem(value: '팩', child: Text('팩')),
                    DropdownMenuItem(value: '박스', child: Text('박스')),
                  ],
                  onChanged: (value) => setDialogState(() => unit = value ?? unit),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('등록')),
          ],
        ),
      ),
    );
    final price = int.tryParse(priceController.text.replaceAll(',', ''));
    if (shouldSave == true && nameController.text.trim().isNotEmpty && price != null && price > 0) {
      store.addProduct(
        name: nameController.text.trim(),
        detail: detailController.text.trim(),
        unit: unit,
        price: price,
      );
    }
    nameController.dispose();
    detailController.dispose();
    priceController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final settings = store.settings;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('관리자 설정', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('도매점 운영 방식에 맞게 기능을 선택하세요.', style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('거래처 가입 승인'),
                subtitle: Text(settings.requireStoreApproval ? '승인된 소매점만 발주할 수 있습니다.' : '가입 즉시 발주할 수 있습니다.'),
                value: settings.requireStoreApproval,
                onChanged: (value) => store.updateSettings((s) => s.requireStoreApproval = value),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('실중량 및 최종금액 확정'),
                subtitle: Text(settings.confirmActualWeight ? '예상금액으로 접수 후 최종금액을 확정합니다.' : '주문 시 금액이 바로 확정됩니다.'),
                value: settings.confirmActualWeight,
                onChanged: (value) => store.updateSettings((s) => s.confirmActualWeight = value),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('최종금액 고객 확인'),
                subtitle: const Text('소매점 확인 후 상품 준비를 시작합니다.'),
                value: settings.requireCustomerConfirmation,
                onChanged: settings.confirmActualWeight
                    ? (value) => store.updateSettings((s) => s.requireCustomerConfirmation = value)
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('거래처별 단가'),
                value: settings.useStoreSpecificPricing,
                onChanged: (value) => store.updateSettings((s) => s.useStoreSpecificPricing = value),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('재고 부족 주문 허용'),
                value: settings.allowBackorder,
                onChanged: (value) => store.updateSettings((s) => s.allowBackorder = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('상품 관리', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            FilledButton.icon(
              onPressed: () => _showAddProductDialog(context, store),
              icon: const Icon(Icons.add),
              label: const Text('상품 등록'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < store.products.length; index++) ...[
                SwitchListTile(
                  title: Text(store.products[index].name),
                  subtitle: Text('${money(store.products[index].price)}원 / ${store.products[index].unit}'),
                  value: store.products[index].isActive,
                  onChanged: (value) => store.toggleProduct(store.products[index], value),
                ),
                if (index < store.products.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 10),
                Expanded(child: Text('설정을 바꿔도 기존 발주는 발주 당시의 설정으로 계속 처리됩니다.')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final isAdmin = store.signedInRole == UserRole.admin;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('내 정보', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.store),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isAdmin ? '마장오더 도매점' : '우리정육점', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(isAdmin ? '관리자 계정' : '승인된 거래처'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Column(
            children: [
              ListTile(leading: Icon(Icons.business_outlined), title: Text('사업자 정보'), trailing: Icon(Icons.chevron_right)),
              Divider(height: 1),
              ListTile(leading: Icon(Icons.location_on_outlined), title: Text('배송지 관리'), trailing: Icon(Icons.chevron_right)),
              Divider(height: 1),
              ListTile(leading: Icon(Icons.notifications_none), title: Text('알림 설정'), trailing: Icon(Icons.chevron_right)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(onPressed: store.signOut, icon: const Icon(Icons.logout), label: const Text('로그아웃')),
      ],
    );
  }
}

String money(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String dateText(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
