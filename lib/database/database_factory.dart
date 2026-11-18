import 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_io.dart'
    if (dart.library.js_interop) 'database_factory_web.dart'
    as factory_impl;

import 'package:sqflite/sqflite.dart';

Future<DatabaseFactory> createDatabaseFactory() =>
    factory_impl.createDatabaseFactory();
