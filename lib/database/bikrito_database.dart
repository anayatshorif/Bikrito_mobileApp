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
        version: 8,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE shop_profile (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            email TEXT NOT NULL DEFAULT '',
            user_id TEXT NOT NULL DEFAULT '',
            pin_hash TEXT NOT NULL DEFAULT '',
            owner TEXT NOT NULL,
            shop TEXT NOT NULL,
            phone TEXT NOT NULL,
            logo_path TEXT,
            logo_data TEXT
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
          if (oldVersion < 6) {
            await db.execute(
              'ALTER TABLE shop_profile ADD COLUMN logo_path TEXT',
            );
            await db.execute(
              'ALTER TABLE shop_profile ADD COLUMN logo_data TEXT',
            );
          }
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE products ADD COLUMN image_data TEXT');
          }
          if (oldVersion < 4) {
            await _ensureSalesTables(db);
          }
          // Sales tables are created fresh for versions before 4, so buyer
          // columns are only missing when upgrading straight from version 4.
          if (oldVersion == 4) {
            await db.execute(
              "ALTER TABLE sales ADD COLUMN buyer_name TEXT NOT NULL DEFAULT ''",
            );
            await db.execute(
              "ALTER TABLE sales ADD COLUMN buyer_phone TEXT NOT NULL DEFAULT ''",
            );
          }
          if (oldVersion < 7) {
            await db.execute(
              "ALTER TABLE sales ADD COLUMN buyer_address TEXT NOT NULL DEFAULT ''",
            );
            await db.execute(
              "ALTER TABLE sales ADD COLUMN delivery_charge REAL NOT NULL DEFAULT 0",
            );
            await db.execute(
              "ALTER TABLE sales ADD COLUMN advance_paid REAL NOT NULL DEFAULT 0",
            );
            await db.execute(
              "ALTER TABLE sales ADD COLUMN cod_due REAL NOT NULL DEFAULT 0",
            );
          }
          if (oldVersion < 8) {
            // Defensive: earlier v7 databases may have been created without
            // the e-commerce columns. Add them only if they are missing.
            await _ensureSalesColumn(db, 'buyer_address', "TEXT NOT NULL DEFAULT ''");
            await _ensureSalesColumn(db, 'delivery_charge', 'REAL NOT NULL DEFAULT 0');
            await _ensureSalesColumn(db, 'advance_paid', 'REAL NOT NULL DEFAULT 0');
            await _ensureSalesColumn(db, 'cod_due', 'REAL NOT NULL DEFAULT 0');
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

  Future<Map<int, int>> getProductSaleCounts() async {
    final db = await database;
    await _ensureSalesTables(db);
    final rows = await db.rawQuery('''
      SELECT product_id, SUM(quantity) as total_qty
      FROM sale_items
      WHERE product_id IS NOT NULL
      GROUP BY product_id
    ''');
    return {
      for (final row in rows)
        (row['product_id'] as num).toInt(): (row['total_qty'] as num).toInt(),
    };
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
        'buyer_name': sale.buyerName,
        'buyer_phone': sale.buyerPhone,
        'buyer_address': sale.buyerAddress,
        'delivery_charge': sale.deliveryCharge,
        'advance_paid': sale.advancePaid,
        'cod_due': sale.codDue,
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
          buyerName: sale['buyer_name'] as String? ?? '',
          buyerPhone: sale['buyer_phone'] as String? ?? '',
          buyerAddress: sale['buyer_address'] as String? ?? '',
          deliveryCharge: (sale['delivery_charge'] as num? ?? 0).toDouble(),
          advancePaid: (sale['advance_paid'] as num? ?? 0).toDouble(),
          codDue: (sale['cod_due'] as num? ?? 0).toDouble(),
        ),
      );
    }
    return records;
  }
}

Future<void> _ensureSalesColumn(
  DatabaseExecutor db,
  String columnName,
  String columnDef,
) async {
  final rows = await db.rawQuery('PRAGMA table_info(sales)');
  var exists = false;
  for (final row in rows) {
    final name = row['name'] as String?;
    if (name == columnName) {
      exists = true;
      break;
    }
  }
  if (!exists) {
    await db.execute('ALTER TABLE sales ADD COLUMN $columnName $columnDef');
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
      created_at INTEGER NOT NULL,
      buyer_name TEXT NOT NULL DEFAULT '',
      buyer_phone TEXT NOT NULL DEFAULT '',
      buyer_address TEXT NOT NULL DEFAULT '',
      delivery_charge REAL NOT NULL DEFAULT 0,
      advance_paid REAL NOT NULL DEFAULT 0,
      cod_due REAL NOT NULL DEFAULT 0
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
