import 'package:flutter/material.dart';

class LanguageService extends ChangeNotifier {
  LanguageService._();

  static final LanguageService instance = LanguageService._();

  static const supportedLocales = [
    Locale('vi'),
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  static const _languageNames = {
    'vi': 'Tiếng Việt',
    'en': 'English',
    'ja': '日本語',
    'zh': '中文',
  };

  Locale _locale = const Locale('vi');

  Locale get locale => _locale;

  String displayName(String code) =>
      _languageNames[code] ?? _languageNames['vi']!;

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }
}
