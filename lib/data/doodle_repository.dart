import 'dart:convert';
import 'dart:io';

import '../models/doodle.dart';

abstract interface class DoodleRepository {
  Future<Map<String, Doodle>> loadAll();

  Future<void> save(String dateKey, Doodle doodle);

  Future<void> delete(String dateKey);

  Future<void> clearAll();

  Future<void> replaceAll(Map<String, Doodle> doodles);
}

class FileDoodleRepository implements DoodleRepository {
  FileDoodleRepository({this.storagePath});

  final String? storagePath;

  @override
  Future<Map<String, Doodle>> loadAll() async {
    final file = await _storageFile();
    if (!await file.exists()) return <String, Doodle>{};

    final encoded = await file.readAsString();
    if (encoded.isEmpty) return <String, Doodle>{};

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return <String, Doodle>{};

      return decoded.map<String, Doodle>((key, value) {
        return MapEntry(
          key.toString(),
          Doodle.fromJson(Map<String, Object?>.from(value as Map)),
        );
      });
    } on FormatException {
      return <String, Doodle>{};
    } on TypeError {
      return <String, Doodle>{};
    }
  }

  @override
  Future<void> save(String dateKey, Doodle doodle) async {
    final doodles = await loadAll();
    doodles[dateKey] = doodle;
    await _write(doodles);
  }

  @override
  Future<void> delete(String dateKey) async {
    final doodles = await loadAll();
    doodles.remove(dateKey);
    await _write(doodles);
  }

  @override
  Future<void> clearAll() async {
    await _write(<String, Doodle>{});
  }

  @override
  Future<void> replaceAll(Map<String, Doodle> doodles) async {
    await _write(Map<String, Doodle>.from(doodles));
  }

  Future<void> _write(Map<String, Doodle> doodles) async {
    final encoded = jsonEncode(
      doodles.map((key, doodle) => MapEntry(key, doodle.toJson())),
    );
    final file = await _storageFile();
    await file.writeAsString(encoded, flush: true);
  }

  Future<File> _storageFile() async {
    if (storagePath case final path?) return File(path);

    final homePath = Platform.environment['HOME'];
    final directory = homePath == null || homePath.isEmpty
        ? Directory.systemTemp
        : Directory('$homePath/Documents');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/dairry_doodles_v1.json');
  }
}

class MemoryDoodleRepository implements DoodleRepository {
  MemoryDoodleRepository([Map<String, Doodle>? initial])
    : _doodles = Map<String, Doodle>.from(initial ?? const {});

  final Map<String, Doodle> _doodles;

  @override
  Future<Map<String, Doodle>> loadAll() async =>
      Map<String, Doodle>.from(_doodles);

  @override
  Future<void> save(String dateKey, Doodle doodle) async {
    _doodles[dateKey] = doodle;
  }

  @override
  Future<void> delete(String dateKey) async {
    _doodles.remove(dateKey);
  }

  @override
  Future<void> clearAll() async {
    _doodles.clear();
  }

  @override
  Future<void> replaceAll(Map<String, Doodle> doodles) async {
    _doodles
      ..clear()
      ..addAll(doodles);
  }
}
