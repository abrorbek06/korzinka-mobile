import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;
  static const String _key = 'app_locale';

  Locale? get locale => _locale;

  LocaleProvider() {
    _loadFromPrefs();
  }

  void setLocale(Locale locale) {
    if (!['uz', 'ru'].contains(locale.languageCode)) return;
    _locale = locale;
    notifyListeners();
    _saveToPrefs(locale);
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_key);
    if (languageCode != null) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }

  Future<void> _saveToPrefs(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }
}
