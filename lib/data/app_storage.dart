import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<Directory> appStorageDirectory() async {
  try {
    final directory = await getApplicationSupportDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  } on MissingPluginException {
    return _fallbackStorageDirectory();
  } on MissingPlatformDirectoryException {
    return _fallbackStorageDirectory();
  }
}

Future<File> appStorageFile(String fileName) async {
  final directory = await appStorageDirectory();
  final file = File('${directory.path}/$fileName');
  if (!await file.exists()) {
    final legacyFile = await legacyStorageFile(fileName);
    if (legacyFile.path != file.path && await legacyFile.exists()) {
      await legacyFile.copy(file.path);
    }
  }
  return file;
}

Future<File> legacyStorageFile(String fileName) async {
  final directory = await _fallbackStorageDirectory();
  return File('${directory.path}/$fileName');
}

Future<Directory> _fallbackStorageDirectory() async {
  final homePath =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  final directory = homePath == null || homePath.isEmpty
      ? Directory.systemTemp
      : Directory('$homePath/Documents');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return directory;
}
