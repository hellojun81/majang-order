import 'package:flutter/material.dart';

void main() => runApp(const MajangOrderApp());

class Product {
  const Product(this.name, this.detail, this.unit, this.price, this.icon);
  final String name;
  final String detail;
  final String unit;
  final int price;
  final IconData icon;
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
}

class AppStore extends ChangeNotifier {
  final settings = OperationSettings();
  final List<CartLine> cart = [];
  final List<DemoOrder> orders = [];

  void add(Product product) {
    final index = cart.indexWhere((line) => line.product.name == product.name);
    if (index < 0) {
      cart.add(CartLine(product));
    } else {
      cart[index].quantity++;
    }
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

  void updateSettings(void Function(OperationSettings value) update) {
    update(settings);
    if (!settings.confirmActualWeight) {
      settings.requireCustomerConfirmation = false;
    }
    notifyListeners();
  }
}

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
        home: const MainShell(),
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
    const pages = [ProductsPage(), CartPage(), OrdersPage(), AdminPage()];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront), label: '상품'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: '장바구니'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: '발주내역'),
          NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: '관리자'),
        ],
      ),
    );
  }
}

const products = [
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
        ...products.map(
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

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('발주내역', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
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
                      Chip(label: Text(order.settings.confirmActualWeight ? '금액 확정 대기' : '접수')),
                    ]),
                    Text(order.lines.map((line) => '${line.product.name} ${line.quantity}${line.product.unit}').join(' · ')),
                    const SizedBox(height: 10),
                    Text('${order.settings.confirmActualWeight ? '예상금액' : '확정금액'} ${money(order.estimatedTotal)}원'),
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

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

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

String money(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
