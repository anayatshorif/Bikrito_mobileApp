import 'dart:io';

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<DatabaseFactory> createDatabaseFactory() async {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }
  return sqflite.databaseFactory;
}
