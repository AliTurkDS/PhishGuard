// lib/services/history_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/scan_record.dart';

class HistoryRepository {
  static HistoryRepository? _instance;
  Database? _db;

  HistoryRepository._();
  static HistoryRepository get instance {
    _instance ??= HistoryRepository._();
    return _instance!;
  }

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'phishing_history.db'),
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT NOT NULL,
            label TEXT NOT NULL,
            confidence REAL NOT NULL,
            is_safe INTEGER NOT NULL,
            scanned_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> insert(ScanRecord record) async {
    final db = await _database;
    await db.insert('scans', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ScanRecord>> getAll({int limit = 100}) async {
    final db = await _database;
    final maps = await db.query('scans',
        orderBy: 'scanned_at DESC', limit: limit);
    return maps.map(ScanRecord.fromMap).toList();
  }

  Future<void> deleteAll() async {
    final db = await _database;
    await db.delete('scans');
  }

  Future<void> deleteById(int id) async {
    final db = await _database;
    await db.delete('scans', where: 'id = ?', whereArgs: [id]);
  }
}
