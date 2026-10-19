import 'package:gal/gal.dart';
import 'package:flutter/services.dart';

import '../models/doodle.dart';
import '../utils/calendar_utils.dart';
import 'story_share_service.dart';

class DoodleGalleryService {
  DoodleGalleryService._();

  static Future<void> save({
    required DateTime date,
    required Doodle doodle,
  }) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess && !await Gal.requestAccess()) {
        throw const DoodleGalleryPermissionException();
      }

      final bytes = await StoryShareService.renderDoodleSquare(doodle: doodle);
      await Gal.putImageBytes(bytes, name: 'drawn-days-${dateKey(date)}');
    } on MissingPluginException {
      throw const DoodleGalleryPluginUnavailableException();
    }
  }
}

class DoodleGalleryPermissionException implements Exception {
  const DoodleGalleryPermissionException();
}

class DoodleGalleryPluginUnavailableException implements Exception {
  const DoodleGalleryPluginUnavailableException();
}
