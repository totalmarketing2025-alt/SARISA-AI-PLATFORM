import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/search_case.dart';

class CaseStorageService {
  CaseStorageService._();

  static final CaseStorageService instance = CaseStorageService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'sarisa_search_cases.db');

    _database = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE search_cases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            case_number TEXT NOT NULL UNIQUE,
            person_name TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            clothing TEXT NOT NULL DEFAULT '',
            last_seen_location TEXT NOT NULL DEFAULT '',
            last_seen_at TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL DEFAULT 'ACTIVE',
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE case_photos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            case_id INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            file_name TEXT NOT NULL,
            added_at TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            FOREIGN KEY (case_id)
              REFERENCES search_cases (id)
              ON DELETE CASCADE
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_case_photos_case_id ON case_photos(case_id)',
        );
      },
    );

    return _database!;
  }

  Future<int> createCase(SearchCase searchCase) async {
    final db = await database;
    final values = searchCase.toMap()..remove('id');
    return db.insert(
      'search_cases',
      values,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<SearchCase>> getCases() async {
    final db = await database;
    final rows = await db.query(
      'search_cases',
      orderBy: 'created_at DESC',
    );
    return rows.map(SearchCase.fromMap).toList();
  }

  Future<SearchCase?> getCase(int id) async {
    final db = await database;
    final rows = await db.query(
      'search_cases',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SearchCase.fromMap(rows.first);
  }

  Future<int> updateCase(SearchCase searchCase) async {
    if (searchCase.id == null) {
      throw ArgumentError('Cannot update a case without an ID.');
    }

    final db = await database;
    final values = searchCase.toMap()..remove('id');
    return db.update(
      'search_cases',
      values,
      where: 'id = ?',
      whereArgs: [searchCase.id],
    );
  }

  Future<int> addPhoto({
    required int caseId,
    required String sourcePath,
    String note = '',
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Selected image does not exist', sourcePath);
    }

    final db = await database;
    final caseExists = await db.query(
      'search_cases',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [caseId],
      limit: 1,
    );

    if (caseExists.isEmpty) {
      throw StateError('Search case not found.');
    }

    final appDirectory = await getApplicationDocumentsDirectory();
    final photoDirectory = Directory(
      p.join(appDirectory.path, 'sarisa_case_photos', caseId.toString()),
    );
    await photoDirectory.create(recursive: true);

    final originalName = p.basename(sourcePath);
    final safeName = originalName.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final destination = p.join(
      photoDirectory.path,
      '${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );

    final copiedFile = await source.copy(destination);

    try {
      return await db.insert('case_photos', {
        'case_id': caseId,
        'file_path': copiedFile.path,
        'file_name': originalName,
        'added_at': DateTime.now().toUtc().toIso8601String(),
        'note': note,
      });
    } catch (_) {
      if (await copiedFile.exists()) await copiedFile.delete();
      rethrow;
    }
  }

  Future<List<CasePhoto>> getPhotos(int caseId) async {
    final db = await database;
    final rows = await db.query(
      'case_photos',
      where: 'case_id = ?',
      whereArgs: [caseId],
      orderBy: 'added_at DESC',
    );
    return rows.map(CasePhoto.fromMap).toList();
  }

  Future<void> deletePhoto(int photoId) async {
    final db = await database;
    final rows = await db.query(
      'case_photos',
      where: 'id = ?',
      whereArgs: [photoId],
      limit: 1,
    );

    if (rows.isEmpty) return;

    final photo = CasePhoto.fromMap(rows.first);
    await db.delete(
      'case_photos',
      where: 'id = ?',
      whereArgs: [photoId],
    );

    final file = File(photo.filePath);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteCase(int caseId) async {
    final db = await database;
    final photos = await getPhotos(caseId);

    await db.delete(
      'search_cases',
      where: 'id = ?',
      whereArgs: [caseId],
    );

    for (final photo in photos) {
      final file = File(photo.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
