// lib/services/client_key.dart
import 'dart:html' as html;
import 'package:uuid/uuid.dart';

class ClientKeyService {
  static const _storageKey = 'client_key';
  static const _uuid = Uuid();

  static String getClientKey() {
    final storage = html.window.localStorage;
    var key = storage[_storageKey];

    if (key == null || key.isEmpty) {
      key = _uuid.v4();
      storage[_storageKey] = key;
    }

    return key;
  }
}
