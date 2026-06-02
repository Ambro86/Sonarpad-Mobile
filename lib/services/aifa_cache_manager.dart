import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sonarpad_mobile_starter/services/aifa_service.dart';

class AifaCacheManager {
  static final AifaCacheManager _instance = AifaCacheManager._internal();
  factory AifaCacheManager() => _instance;
  AifaCacheManager._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'aifa_cache.db');

    // Check if db exists
    final exists = await databaseExists(path);
    if (!exists) {
      await _copySeed(path);
    }

    try {
      return await _openDb(path);
    } catch (e) {
      // Possible corruption
      final brokenPath = join(dbPath, 'aifa_cache.broken.db');
      try {
        if (await File(path).exists()) {
          await File(path).rename(brokenPath);
        }
      } catch (_) {}
      await _copySeed(path);
      // Ritentiamo
      return await _openDb(path);
    }
  }

  Future<void> _copySeed(String path) async {
    try {
      await Directory(dirname(path)).create(recursive: true);
      ByteData data = await rootBundle.load('assets/aifa_cache_seed.db');
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
    } catch (e) {
      // Ignora se non c'è seed, verrà creato vuoto da onCreate
    }
  }

  Future<Database> _openDb(String path) async {
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE drugs(
            aic9 TEXT PRIMARY KEY,
            denominazione TEXT,
            principi_attivi TEXT,
            normalized_name TEXT,
            normalized_active_ingredients TEXT,
            ocr_aliases TEXT,
            confezioni_json TEXT
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_drugs_normalized_name ON drugs(normalized_name);
        ''');
        await db.execute('''
          CREATE INDEX idx_drugs_active_ingredients ON drugs(normalized_active_ingredients);
        ''');
        await db.execute('''
          CREATE TABLE cache_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.insert('cache_metadata',
            {'key': 'aifa_dataset_version', 'value': '1.0.0'});
        await db
            .insert('cache_metadata', {'key': 'schema_version', 'value': '1'});
      },
    );
  }

  Future<void> insertOrUpdateDrug(AifaDrugResult drug) async {
    final db = await database;
    await _insertDrug(db, drug);
  }

  Future<void> insertOrUpdateDrugList(List<AifaDrugResult> drugs) async {
    final db = await database;
    final batch = db.batch();
    for (var drug in drugs) {
      final normalizedName = _normalizeName(drug.denominazione);
      final normalizedAi = _normalizeName(drug.principiAttivi);
      final confezioniJson = jsonEncode(drug.confezioni
          .map((c) => {
                'name': c.name,
                'codiceSis': c.codiceSis,
                'aic6': c.aic6,
              })
          .toList());

      batch.insert(
        'drugs',
        {
          'aic9': drug.aic9,
          'denominazione': drug.denominazione,
          'principi_attivi': drug.principiAttivi,
          'normalized_name': normalizedName,
          'normalized_active_ingredients': normalizedAi,
          'ocr_aliases': '',
          'confezioni_json': confezioniJson,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _insertDrug(Database db, AifaDrugResult drug) async {
    final normalizedName = _normalizeName(drug.denominazione);
    final normalizedAi = _normalizeName(drug.principiAttivi);
    final confezioniJson = jsonEncode(drug.confezioni
        .map((c) => {
              'name': c.name,
              'codiceSis': c.codiceSis,
              'aic6': c.aic6,
            })
        .toList());

    await db.insert(
      'drugs',
      {
        'aic9': drug.aic9,
        'denominazione': drug.denominazione,
        'principi_attivi': drug.principiAttivi,
        'normalized_name': normalizedName,
        'normalized_active_ingredients': normalizedAi,
        'ocr_aliases': '',
        'confezioni_json': confezioniJson,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AifaDrugResult?> getDrugByAic(String aic9) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'drugs',
      where: 'aic9 = ?',
      whereArgs: [aic9],
    );

    if (maps.isNotEmpty) {
      return _mapToDrugResult(maps.first);
    }
    return null;
  }

  Future<Map<String, String>> getDatabaseMetadata() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cache_metadata');
    final Map<String, String> meta = {};
    for (var m in maps) {
      meta[m['key'] as String] = m['value'] as String;
    }
    return meta;
  }

  // Pre-filtro SQL, ritorna un po' di roba che la Dart similarity poi raffinerà
  Future<List<AifaDrugResult>> searchDrugsByNormalizedName(
      String rawName) async {
    final db = await database;
    final normalized = _normalizeName(rawName);
    if (normalized.isEmpty) return [];

    final searchTerm = '%$normalized%';
    final List<Map<String, dynamic>> maps = await db.query(
      'drugs',
      where: 'normalized_name LIKE ? OR ocr_aliases LIKE ?',
      whereArgs: [searchTerm, searchTerm],
    );

    return maps.map((map) => _mapToDrugResult(map)).toList();
  }

  String _normalizeName(String name) {
    String norm = name.toUpperCase();
    norm = norm.replaceAll('1', 'I');
    norm = norm.replaceAll('L', 'I');
    norm = norm.replaceAll('0', 'O');
    norm = norm.replaceAll(RegExp(r'[^A-Z]'), '');
    return norm;
  }

  AifaDrugResult _mapToDrugResult(Map<String, dynamic> map) {
    final List<dynamic> confList = jsonDecode(map['confezioni_json'] as String);
    final confezioni = confList
        .map((c) => AifaConfezione(
              name: c['name'] as String,
              codiceSis: c['codiceSis'] as String,
              aic6: c['aic6'] as String,
            ))
        .toList();

    return AifaDrugResult(
      denominazione: map['denominazione'] as String,
      principiAttivi: map['principi_attivi'] as String,
      aic9: map['aic9'] as String,
      confezioni: confezioni,
    );
  }
}
