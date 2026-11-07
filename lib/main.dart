import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  runApp(const AsmakAlbarakaApp());
}

class AsmakAlbarakaApp extends StatelessWidget {
  const AsmakAlbarakaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'أسماك البركة',
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF087E8B),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F8F8),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF087E8B),
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            elevation: 1,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        home: const HomePage(),
      );
}

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'asmak_albaraka.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE fish_types (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          price_per_kg REAL NOT NULL CHECK(price_per_kg >= 0),
          active INTEGER NOT NULL DEFAULT 1
        )''');
        await db.execute('''CREATE TABLE customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT NOT NULL DEFAULT '',
          notes TEXT NOT NULL DEFAULT ''
        )''');
        await db.execute('''CREATE TABLE reservations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER,
          customer_name TEXT NOT NULL,
          customer_phone TEXT NOT NULL DEFAULT '',
          pickup_at TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'جديد',
          total REAL NOT NULL DEFAULT 0,
          paid REAL NOT NULL DEFAULT 0,
          notes TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          FOREIGN KEY(customer_id) REFERENCES customers(id)
        )''');
        await db.execute('''CREATE TABLE reservation_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reservation_id INTEGER NOT NULL,
          fish_type_id INTEGER,
          fish_name TEXT NOT NULL,
          quantity_kg REAL NOT NULL CHECK(quantity_kg > 0),
          unit_price REAL NOT NULL CHECK(unit_price >= 0),
          line_total REAL NOT NULL,
          FOREIGN KEY(reservation_id) REFERENCES reservations(id) ON DELETE CASCADE
        )''');
        await db.execute('''CREATE TABLE payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reservation_id INTEGER NOT NULL,
          amount REAL NOT NULL CHECK(amount > 0),
          paid_at TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          FOREIGN KEY(reservation_id) REFERENCES reservations(id) ON DELETE CASCADE
        )''');
        await db.insert('fish_types', {'name': 'سمك ثمد', 'price_per_kg': 0});
        await db.insert('fish_types', {'name': 'سمك白', 'price_per_kg': 0});
      },
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
    return _db!;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _reservations = 0;
  double _outstanding = 0;
  double _todaySales = 0;
  bool _loading = true;
  final _currency = NumberFormat('#,##0.##', 'en');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c, COALESCE(SUM(total-paid),0) AS debt FROM reservations WHERE status != ?', ['ملغي']);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final sales = await db.rawQuery('SELECT COALESCE(SUM(total),0) AS amount FROM reservations WHERE substr(created_at,1,10)=? AND status != ?', [today, 'ملغي']);
    if (!mounted) return;
    setState(() {
      _reservations = (rows.first['c'] as int?) ?? 0;
      _outstanding = (rows.first['debt'] as num?)?.toDouble() ?? 0;
      _todaySales = (sales.first['amount'] as num?)?.toDouble() ?? 0;
      _loading = false;
    });
  }

  String money(double value) => '${_currency.format(value)} ر.ي';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('أسماك البركة', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'تحديث')],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF087E8B), Color(0xFF075B66)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مرحباً بك', style: TextStyle(color: Colors.white70, fontSize: 15)),
                  SizedBox(height: 8),
                  Text('إدارة حجوزات الأسماك بسهولة', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                  SizedBox(height: 5),
                  Text('كل بياناتك محفوظة على جهازك وتعمل دون إنترنت', style: TextStyle(color: Colors.white70)),
                ]),
              ),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(),
              Row(children: [
                Expanded(child: _StatCard(title: 'الحجوزات', value: '$_reservations', icon: Icons.receipt_long)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(title: 'مبيعات اليوم', value: money(_todaySales), icon: Icons.point_of_sale)),
              ]),
              const SizedBox(height: 10),
              _StatCard(title: 'المبالغ المتبقية', value: money(_outstanding), icon: Icons.account_balance_wallet, wide: true),
              const SizedBox(height: 22),
              const Text('إدارة المحل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _MenuTile(icon: Icons.add_shopping_cart, title: 'حجز جديد', subtitle: 'تسجيل طلب عميل ووزن السمك', onTap: () => _openPlaceholder('حجز جديد')),
              _MenuTile(icon: Icons.list_alt, title: 'الحجوزات', subtitle: 'متابعة حالة الطلبات والاستلام', onTap: () => _openPlaceholder('الحجوزات')),
              _MenuTile(icon: Icons.set_meal, title: 'الأسماك والأسعار', subtitle: 'إضافة الأصناف وتعديل سعر الكيلو', onTap: () => _openPlaceholder('الأسماك والأسعار')),
              _MenuTile(icon: Icons.people_alt, title: 'العملاء', subtitle: 'بيانات العملاء وأرقام التواصل', onTap: () => _openPlaceholder('العملاء')),
              _MenuTile(icon: Icons.payments, title: 'المدفوعات والديون', subtitle: 'تسجيل الدفعات ومراجعة المتبقي', onTap: () => _openPlaceholder('المدفوعات والديون')),
              _MenuTile(icon: Icons.bar_chart, title: 'التقارير', subtitle: 'ملخص يومي وشهري وكشف حساب', onTap: () => _openPlaceholder('التقارير')),
              _MenuTile(icon: Icons.backup, title: 'النسخ الاحتياطي', subtitle: 'حفظ نسخة من بيانات التطبيق واستعادتها', onTap: () => _openPlaceholder('النسخ الاحتياطي')),
              const SizedBox(height: 16),
              const Center(child: Text('أسماك البركة • الإصدار الأولي', style: TextStyle(color: Colors.black45))),
            ],
          ),
        ),
      );

  void _openPlaceholder(String name) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('سيتم تجهيز شاشة $name في المرحلة التالية')));
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon, this.wide = false});
  final String title;
  final String value;
  final IconData icon;
  final bool wide;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(backgroundColor: const Color(0xFFE2F2F2), child: Icon(icon, color: const Color(0xFF087E8B))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 4),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ])),
          ]),
        ),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(backgroundColor: const Color(0xFFE2F2F2), child: Icon(icon, color: const Color(0xFF087E8B))),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_left),
        ),
      );
}
