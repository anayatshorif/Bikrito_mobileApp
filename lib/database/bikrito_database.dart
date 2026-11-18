import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_factory.dart';
import '../models/shop_profile.dart';
import '../models/shop_product.dart';
import '../models/sale_record.dart';

/// Local SQLite storage for the Bikrito shop profile and product catalog.
class BikritoDatabase {
  BikritoDatabase._();

  static final BikritoDatabase instance = BikritoDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final factory = await createDatabaseFactory();
    final dbPath = p.join(await factory.getDatabasesPath(), 'bikrito.db');
    _database = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE shop_profile (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            email TEXT NOT NULL DEFAULT '',
            user_id TEXT NOT NULL DEFAULT '',
            pin_hash TEXT NOT NULL DEFAULT '',
            owner TEXT NOT NULL,
            shop TEXT NOT NULL,
            phone TEXT NOT NULL
          )
          ''');
          await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            image_path TEXT,
            image_data TEXT
          )
          ''');
          await _ensureSalesTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              "ALTER TABLE shop_profile ADD COLUMN email TEXT NOT NULL DEFAULT ''",
            );
            await db.execute(
              "ALTER TABLE shop_profile ADD COLUMN user_id TEXT NOT NULL DEFAULT ''",
            );
            await db.execute(
              "ALTER TABLE shop_profile ADD COLUMN pin_hash TEXT NOT NULL DEFAULT ''",
            );
          }
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE products ADD COLUMN image_data TEXT');
          }
          if (oldVersion < 4) {
            await _ensureSalesTables(db);
          }
        },
      ),
    );
    return _database!;
  }

  Future<ShopProfile?> getProfile() async {
    final rows = await (await database).query('shop_profile', where: 'id = 1');
    if (rows.isEmpty) return null;
    return ShopProfile.fromJson(rows.first);
  }

  Future<void> saveProfile(ShopProfile profile) async {
    await (await database).insert('shop_profile', {
      'id': 1,
      ...profile.toJson(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ShopProduct>> getProducts() async {
    final rows = await (await database).query('products', orderBy: 'id DESC');
    return rows.map(ShopProduct.fromJson).toList();
  }

  Future<int> addProduct(ShopProduct product) async =>
      (await database).insert('products', {
        'name': product.name,
        'price': product.price,
        'image_path': product.imagePath,
        'image_data': product.imageData,
      });

  Future<void> deleteProduct(int id) async {
    await (await database).delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> createSale(SaleRecord sale) async {
    final db = await database;
    return db.transaction((txn) async {
      await _ensureSalesTables(txn);
      final saleId = await txn.insert('sales', {
        'subtotal': sale.subtotal,
        'discount': sale.discount,
        'total': sale.total,
        'payment_method': sale.paymentMethod,
        'created_at': sale.createdAt.millisecondsSinceEpoch,
      });
      for (final item in sale.items) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.productId,
          'product_name': item.name,
          'unit_price': item.unitPrice,
          'quantity': item.quantity,
        });
      }
      return saleId;
    });
  }

  Future<List<SaleRecord>> getSales() async {
    final db = await database;
    await _ensureSalesTables(db);
    final sales = await db.query('sales', orderBy: 'created_at DESC, id DESC');
    final records = <SaleRecord>[];
    for (final sale in sales) {
      final saleId = sale['id'] as int;
      final itemRows = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
        orderBy: 'id ASC',
      );
      records.add(
        SaleRecord(
          id: saleId,
          items: itemRows
              .map(
                (item) => SaleItem(
                  productId: item['product_id'] as int?,
                  name: item['product_name'] as String,
                  unitPrice: (item['unit_price'] as num).toDouble(),
                  quantity: item['quantity'] as int,
                ),
              )
              .toList(),
          subtotal: (sale['subtotal'] as num).toDouble(),
          discount: (sale['discount'] as num).toDouble(),
          total: (sale['total'] as num).toDouble(),
          paymentMethod: sale['payment_method'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            sale['created_at'] as int,
          ),
        ),
      );
    }
    return records;
  }
}

Future<void> _ensureSalesTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subtotal REAL NOT NULL,
      discount REAL NOT NULL DEFAULT 0,
      total REAL NOT NULL,
      payment_method TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS sale_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL,
      product_id INTEGER,
      product_name TEXT NOT NULL,
      unit_price REAL NOT NULL,
      quantity INTEGER NOT NULL,
      FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE
    )
  ''');
}
