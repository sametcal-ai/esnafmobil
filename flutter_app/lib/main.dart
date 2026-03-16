import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/app.dart';
import 'core/config/hive_migrations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await Hive.initFlutter();
  await Hive.openBox('users');
  await Hive.openBox('session');
  await Hive.openBox('customers');
  await Hive.openBox('customer_ledger');
  await Hive.openBox('products');
  await Hive.openBox('suppliers');
  await Hive.openBox('supplier_ledger');
  await Hive.openBox('stock_entries');
  await Hive.openBox('barcode_cache');
  await Hive.openBox('sales');
  await Hive.openBox('held_sales');

  await HiveMigrations.runAll();

  runApp(const ProviderScope(child: App()));
}