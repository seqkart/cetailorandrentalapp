import 'package:flutter/material.dart';

import 'session_store.dart';

class AppLocaleController extends ValueNotifier<Locale> {
  AppLocaleController(this._sessionStore) : super(const Locale('en'));

  final SessionStore _sessionStore;
  static const _supportedLanguageCodes = {'en', 'hi', 'pa'};

  Future<void> load() async {
    final savedCode = await _sessionStore.readLocale();
    if (savedCode != null && _supportedLanguageCodes.contains(savedCode)) {
      value = Locale(savedCode);
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!_supportedLanguageCodes.contains(locale.languageCode)) {
      throw ArgumentError.value(locale, 'locale', 'Unsupported app language.');
    }
    await _sessionStore.writeLocale(locale.languageCode);
    value = locale;
  }
}
