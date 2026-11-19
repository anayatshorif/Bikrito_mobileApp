-- Bikrito local SQLite database schema (database version 6).
-- The app creates this database on the device as bikrito.db.

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
);

CREATE TABLE products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  price REAL NOT NULL,
  image_path TEXT,
  image_data TEXT
);

CREATE TABLE sales (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subtotal REAL NOT NULL,
  discount REAL NOT NULL DEFAULT 0,
  total REAL NOT NULL,
  payment_method TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  buyer_name TEXT NOT NULL DEFAULT '',
  buyer_phone TEXT NOT NULL DEFAULT ''
);

CREATE TABLE sale_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sale_id INTEGER NOT NULL,
  product_id INTEGER,
  product_name TEXT NOT NULL,
  unit_price REAL NOT NULL,
  quantity INTEGER NOT NULL,
  FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE
);
