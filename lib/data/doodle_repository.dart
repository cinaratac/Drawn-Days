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
  Map<String, Doodle>? _cache;
  Future<Map<String, Doodle>>? _loadInFlight;

  @override
  Future<Map<String, Doodle>> loadAll() async {
    final cached = _cache;
    if (cached != null) return Map<String, Doodle>.from(cached);

    final activeLoad = _loadInFlight;
    if (activeLoad != null) {
      return Map<String, Doodle>.from(await activeLoad);
    }

    final load = _loadFromDisk();
    _loadInFlight = load;
    try {
      return Map<String, Doodle>.from(await load);
    } finally {
      if (identical(_loadInFlight, load)) _loadInFlight = null;
    }
  }

  Future<Map<String, Doodle>> _loadFromDisk() async {
    final file = await _storageFile();
    if (!await file.exists()) {
      _cache = <String, Doodle>{};
      return <String, Doodle>{};
    }

    final encoded = await file.readAsString();
    if (encoded.isEmpty) {
      _cache = <String, Doodle>{};
      return <String, Doodle>{};
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return <String, Doodle>{};

      final doodles = decoded.map<String, Doodle>((key, value) {
        return MapEntry(
          key.toString(),
          Doodle.fromJson(Map<String, Object?>.from(value as Map)),
        );
      });
      _cache = doodles;
      return Map<String, Doodle>.from(doodles);
    } on FormatException {
      _cache = <String, Doodle>{};
      return <String, Doodle>{};
    } on TypeError {
      _cache = <String, Doodle>{};
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
    _cache = Map<String, Doodle>.from(doodles);
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
    return File('${directory.path}/drawn_days_doodles_v1.json');
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
