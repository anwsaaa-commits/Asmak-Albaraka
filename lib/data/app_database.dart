import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(p.join(root, 'asmak_albaraka.db'), version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE fish_types (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, price_per_kg REAL NOT NULL CHECK(price_per_kg >= 0), active INTEGER NOT NULL DEFAULT 1)');
        await db.execute("CREATE TABLE customers (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '')");
        await db.execute("CREATE TABLE reservations (id INTEGER PRIMARY KEY AUTOINCREMENT, customer_id INTEGER, customer_name TEXT NOT NULL, customer_phone TEXT NOT NULL DEFAULT '', pickup_at TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'جديد', total REAL NOT NULL DEFAULT 0, paid REAL NOT NULL DEFAULT 0, notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL, FOREIGN KEY(customer_id) REFERENCES customers(id))");
        await db.execute('CREATE TABLE reservation_items (id INTEGER PRIMARY KEY AUTOINCREMENT, reservation_id INTEGER NOT NULL, fish_type_id INTEGER, fish_name TEXT NOT NULL, quantity_kg REAL NOT NULL CHECK(quantity_kg > 0), unit_price REAL NOT NULL CHECK(unit_price >= 0), line_total REAL NOT NULL, FOREIGN KEY(reservation_id) REFERENCES reservations(id) ON DELETE CASCADE)');
        await db.execute("CREATE TABLE payments (id INTEGER PRIMARY KEY AUTOINCREMENT, reservation_id INTEGER NOT NULL, amount REAL NOT NULL CHECK(amount > 0), paid_at TEXT NOT NULL, note TEXT NOT NULL DEFAULT '', FOREIGN KEY(reservation_id) REFERENCES reservations(id) ON DELETE CASCADE)");
        await db.execute('CREATE INDEX idx_reservations_pickup ON reservations(pickup_at)');
        await db.execute('CREATE INDEX idx_reservations_phone ON reservations(customer_phone)');
      });
    return _db!;
  }

  Future<String> get databasePath async => p.join(await getDatabasesPath(), 'asmak_albaraka.db');

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<List<Map<String,Object?>>> getFish() async => (await database).query('fish_types', where: 'active=1', orderBy: 'name');
  Future<int> saveFish({int? id, required String name, required double price}) async {
    final db = await database;
    final values = {'name': name.trim(), 'price_per_kg': price, 'active': 1};
    return id == null ? db.insert('fish_types', values) : db.update('fish_types', values, where: 'id=?', whereArgs: [id]);
  }
  Future<int> archiveFish(int id) async => (await database).update('fish_types', {'active':0}, where:'id=?', whereArgs:[id]);

  Future<int> createReservation({required String customerName, required String phone, required DateTime pickupAt, required List<Map<String,Object?>> items, required double paid, String notes = ''}) async {
    if (items.isEmpty || customerName.trim().isEmpty) throw ArgumentError('أدخل اسم العميل وصنفًا واحدًا على الأقل');
    final total = items.fold<double>(0, (sum, x) => sum + (x['quantity_kg'] as num).toDouble() * (x['unit_price'] as num).toDouble());
    if (paid < 0 || paid > total) throw ArgumentError('تحقق من المبلغ المدفوع');
    final db = await database;
    return db.transaction((txn) async {
      final phoneValue = phone.trim();
      final found = phoneValue.isEmpty ? <Map<String,Object?>>[] : await txn.query('customers', where:'phone=?', whereArgs:[phoneValue], limit:1);
      final customerId = found.isNotEmpty ? found.first['id'] as int : await txn.insert('customers', {'name':customerName.trim(),'phone':phoneValue});
      final id = await txn.insert('reservations', {'customer_id':customerId,'customer_name':customerName.trim(),'customer_phone':phoneValue,'pickup_at':pickupAt.toIso8601String(),'status':'جديد','total':total,'paid':paid,'notes':notes.trim(),'created_at':DateTime.now().toIso8601String()});
      for (final x in items) {
        final q = (x['quantity_kg'] as num).toDouble();
        final price = (x['unit_price'] as num).toDouble();
        await txn.insert('reservation_items', {'reservation_id':id,'fish_type_id':x['fish_type_id'],'fish_name':x['fish_name'],'quantity_kg':q,'unit_price':price,'line_total':q*price});
      }
      if (paid > 0) await txn.insert('payments', {'reservation_id':id,'amount':paid,'paid_at':DateTime.now().toIso8601String(),'note':'دفعة عند إنشاء الحجز'});
      return id;
    });
  }

  Future<List<Map<String,Object?>>> getReservations({String search = ''}) async {
    final q = search.trim();
    return (await database).query('reservations', where:q.isEmpty?null:'customer_name LIKE ? OR customer_phone LIKE ?', whereArgs:q.isEmpty?null:['%$q%','%$q%'], orderBy:'pickup_at DESC');
  }
  Future<void> updateStatus(int id, String status) async {
    const allowed = ['جديد','مؤكد','قيد التجهيز','تم التسليم','ملغي'];
    if (!allowed.contains(status)) throw ArgumentError('حالة غير صحيحة');
    await (await database).update('reservations', {'status':status}, where:'id=?', whereArgs:[id]);
  }
  Future<void> addPayment(int id, double amount) async {
    if (amount <= 0) throw ArgumentError('المبلغ يجب أن يكون أكبر من صفر');
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('reservations', where:'id=?', whereArgs:[id], limit:1);
      if (rows.isEmpty) throw StateError('الحجز غير موجود');
      final total = (rows.first['total'] as num).toDouble();
      final paid = (rows.first['paid'] as num).toDouble();
      if (paid + amount > total) throw ArgumentError('المبلغ أكبر من المتبقي');
      await txn.insert('payments', {'reservation_id':id,'amount':amount,'paid_at':DateTime.now().toIso8601String(),'note':''});
      await txn.update('reservations', {'paid':paid+amount}, where:'id=?', whereArgs:[id]);
    });
  }
}
