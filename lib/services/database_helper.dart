import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'dictionary.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT
      )
    ''');
  }

  Future<void> insertFavorite(String word) async {
    final db = await database;
    await db.insert(
      'favorites',
      {'word': word},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertHistory(String word) async {
    final db = await database;
    await db.insert(
      'history',
      {'word': word},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> getFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('favorites');

    return List.generate(maps.length, (i) {
      return maps[i]['word'];
    });
  }

  Future<List<String>> getHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('history');

    return List.generate(maps.length, (i) {
      return maps[i]['word'];
    });
  }

  Future<void> deleteFavorite(String word) async {
    final db = await database;
    await db.delete('favorites', where: 'word = ?', whereArgs: [word]);
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('history');
  }
}
