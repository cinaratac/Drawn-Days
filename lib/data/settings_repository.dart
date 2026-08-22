import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

class FileSettingsRepository implements SettingsRepository {
  FileSettingsRepository({this.storagePath});

  final String? storagePath;

  @override
  Future<AppSettings> load() async {
    final file = await _storageFile();
    if (!await file.exists()) return const AppSettings();

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return const AppSettings();
      return AppSettings.fromJson(Map<String, Object?>.from(decoded));
    } on FormatException {
      return const AppSettings();
    } on TypeError {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    final file = await _storageFile();
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
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
    return File('${directory.path}/drawn_days_settings_v1.json');
  }
}

class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository([this._settings = const AppSettings()]);

  AppSettings _settings;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}
