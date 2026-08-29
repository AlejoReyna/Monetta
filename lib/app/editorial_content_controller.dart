/// Cache-safe owner content for the About and reseller experiences.
library;

import 'package:flutter/foundation.dart';

import '../data/shopify/editorial_content_repository.dart';
import '../domain/editorial_content.dart';

class EditorialContentController extends ChangeNotifier {
  EditorialContentController({EditorialContentRepository? repository})
      : _repository = repository;

  final EditorialContentRepository? _repository;
  MonettaEditorialContent _content = MonettaEditorialContent.fallback;

  MonettaEditorialContent get content => _content;

  /// Best effort by design: the bundled fallback is already complete, and an
  /// unavailable or partially configured Metaobject must not block the app.
  Future<void> refresh() async {
    final repository = _repository;
    if (repository == null) return;
    try {
      _content = await repository.fetch();
      notifyListeners();
    } on Object {
      // Retain the bundled/last-known in-memory content.
    }
  }
}
