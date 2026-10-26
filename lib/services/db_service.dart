import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/schedule_task.dart';

class DBService {
  static const String _dbName = 'task_scheduler.db';
  static const int _dbVersion = 1;
  static const String tableName = 'tasks';

  DBService._internal();
  static final DBService instance = DBService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static const String settingsTable = 'app_settings';

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        scheduledTime TEXT NOT NULL,
        status TEXT NOT NULL,
        voiceNotePath TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $settingsTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onOpen(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $settingsTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    try {
      await db.execute('ALTER TABLE $tableName ADD COLUMN voiceNotePath TEXT');
    } catch (_) {
      // Column already exists, safe to ignore
    }
  }

  /// Inserts a task and returns the inserted autoincrement primary key ID.
  Future<int> insertTask(ScheduleTask task) async {
    final db = await database;
    final id = await db.insert(
      tableName,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  /// Fetches all tasks sorted chronologically by scheduled date/time ascending.
  Future<List<ScheduleTask>> getAllTasks() async {
    final db = await database;
    final results = await db.query(
      tableName,
      orderBy: 'scheduledTime ASC',
    );
    return results.map((map) => ScheduleTask.fromMap(map)).toList();
  }

  /// Updates task status by task ID ('pending', 'completed', 'cancelled').
  Future<int> updateTaskStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      tableName,
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Updates full task details (title, scheduledTime, status).
  Future<int> updateTask(ScheduleTask task) async {
    if (task.id == null) return 0;
    final db = await database;
    return await db.update(
      tableName,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  /// Optional helper: Fetches a single task by ID.
  Future<ScheduleTask?> getTaskById(int id) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ScheduleTask.fromMap(results.first);
  }

  /// Optional helper: Deletes a task by ID.
  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Fetches a persistent setting value by key.
  Future<String?> getSetting(String key, {String? defaultValue}) async {
    final db = await database;
    final results = await db.query(
      settingsTable,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (results.isEmpty) return defaultValue;
    return results.first['value'] as String?;
  }

  /// Persists a setting value by key.
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      settingsTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Closes database.
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
