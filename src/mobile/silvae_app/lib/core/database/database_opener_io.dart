import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Su Android e iOS il plugin nativo è già registrato.
DatabaseFactory localDatabaseFactory() => databaseFactory;

Future<String> localDatabasePath() async =>
    p.join(await getDatabasesPath(), 'silvae.db');
