import 'dart:io';

import 'package:in_app_review/in_app_review.dart';

abstract interface class AppReviewService {
  bool get canOpenStoreListing;

  Future<void> requestReview();

  Future<void> openStoreListing();
}

class StoreAppReviewService implements AppReviewService {
  StoreAppReviewService({InAppReview? inAppReview})
    : _inAppReview = inAppReview ?? InAppReview.instance;

  static const String _appStoreId = '6808263452';

  final InAppReview _inAppReview;

  @override
  bool get canOpenStoreListing =>
      Platform.isAndroid ||
      Platform.isWindows ||
      Platform.isIOS ||
      Platform.isMacOS;

  @override
  Future<void> requestReview() async {
    if (await _inAppReview.isAvailable()) {
      await _inAppReview.requestReview();
    }
  }

  @override
  Future<void> openStoreListing() async {
    await _inAppReview.openStoreListing(appStoreId: _appStoreId);
  }
}

class MemoryAppReviewService implements AppReviewService {
  int requestReviewCount = 0;
  int openStoreListingCount = 0;

  @override
  bool canOpenStoreListing = true;

  @override
  Future<void> requestReview() async {
    requestReviewCount++;
  }

  @override
  Future<void> openStoreListing() async {
    openStoreListingCount++;
  }
}
