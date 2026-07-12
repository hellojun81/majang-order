import 'package:flutter/material.dart';

void main() => runApp(const MajangOrderApp());

class Product {
  Product(this.name, this.detail, this.unit, this.price, this.icon, {this.isActive = true});
  final String name;
  final String detail;
  final String unit;
  final int price;
  final IconData icon;
  bool isActive;
}

class CartLine {
  CartLine(this.product, {this.quantity = 1});
  final Product product;
  int quantity;
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
}

class DemoOrder {
  DemoOrder(this.number, this.lines, this.estimatedTotal, this.settings);
  final String number;
  final List<CartLine> lines;
  final int estimatedTotal;
  final OperationSettings settings;
  OrderStage stage = OrderStage.pending;
  int? finalTotal;
}

enum OrderStage { pending, weighing, customerConfirmation, preparing, rejected }

class AppStore extends ChangeNotifier {
  final settings = OperationSettings();
  final List<Product> products = initialProducts
      .map((product) => Product(product.name, product.detail, product.unit, product.price, product.icon))
      .toList();
  final List<CartLine> cart = [];
  final List<DemoOrder> orders = [];
  UserRole? signedInRole;
  bool retailerApproved = false;

  void signIn(UserRole role) {
    signedInRole = role;
    retailerApproved = role == UserRole.admin || !settings.requireStoreApproval;
    notifyListeners();
  }

  void approveDemoRetailer() {
    retailerApproved = true;
    notifyListeners();
  }

  void signOut() {
    signedInRole = null;
    retailerApproved = false;
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
    notifyListeners();
  }

  void toggleProduct(Product product, bool isActive) {
    product.isActive = isActive;
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

  void placeOrder() {
    if (cart.isEmpty) return;
    orders.insert(
      0,
      DemoOrder(
        'MO-${1001 + orders.length}',
        cart.map((line) => CartLine(line.product, quantity: line.quantity)).toList(),
        cartTotal,
        settings.snapshot(),
      ),
    );
    cart.clear();
    notifyListeners();
  }

  void acceptOrder(DemoOrder order) {
    order.stage = order.settings.confirmActualWeight ? OrderStage.weighing : OrderStage.preparing;
    if (!order.settings.confirmActualWeight) order.finalTotal = order.estimatedTotal;
    notifyListeners();
  }

  void rejectOrder(DemoOrder order) {
    order.stage = OrderStage.rejected;
    notifyListeners();
  }

  void confirmFinalAmount(DemoOrder order, int amount) {
    order.finalTotal = amount;
    order.stage = order.settings.requireCustomerConfirmation
        ? OrderStage.customerConfirmation
        : OrderStage.preparing;
    notifyListeners();
  }

  void confirmOrderAsCustomer(DemoOrder order) {
    order.stage = OrderStage.preparing;
    notifyListeners();
  }

  void updateSettings(void Function(OperationSettings value) update) {
    update(settings);
    if (!settings.confirmActualWeight) {
      settings.requireCustomerConfirmation = false;
    }
    notifyListeners();
  }
}

enum UserRole { retailer, admin }

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
    if (store.signedInRole == UserRole.retailer && !store.retailerApproved) {
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
                  const Text(
                    '현재는 화면 확인용 데모 로그인입니다. 다음 단계에서 Supabase 인증으로 교체합니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
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
                  const Icon(Icons.hourglass_top_rounded, size: 72, color: Color(0xFF8E2B25)),
                  const SizedBox(height: 22),
                  const Text('거래처 승인 대기 중', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text('도매점 확인이 끝나면 상품 조회와 발주를 시작할 수 있습니다.', textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: store.approveDemoRetailer,
                      child: const Text('데모 승인 완료 처리'),
                    ),
                  ),
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
            const Expanded(child: _SummaryCard(label: '승인 대기', value: '1', icon: Icons.store_mall_directory)),
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
        const Card(
          child: Column(
            children: [
              ListTile(leading: Icon(Icons.person_add_alt), title: Text('신규 거래처 승인'), trailing: Icon(Icons.chevron_right)),
              Divider(height: 1),
              ListTile(leading: Icon(Icons.add_box_outlined), title: Text('상품 등록 및 단가 관리'), trailing: Icon(Icons.chevron_right)),
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
