import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Sul web SQLite è compilato in WebAssembly. Il file che gli serve,
/// `sqlite3.wasm`, lo scarica dentro `web/` il comando
/// `dart run sqflite_common_ffi_web:setup`.
///
/// Gira sull'isolate principale invece che in un worker condiviso:
/// `databaseFactoryFfiWeb` fallisce l'apertura con `unsupported result null`,
/// perché il worker precompilato non risponde alla `openDatabase` di
/// `sqflite_common`. Il costo è che le query non lasciano il thread della UI,
/// trascurabile per il volume di un rapportino.
DatabaseFactory localDatabaseFactory() => databaseFactoryFfiWebNoWebWorker;

/// Non è un percorso su disco ma il nome dello store IndexedDB: sul web non
/// esiste una cartella dei database da cui derivarlo.
Future<String> localDatabasePath() async => 'silvae.db';
