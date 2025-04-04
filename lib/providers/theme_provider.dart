import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _highContrast = false;
  bool get highContrast => _highContrast;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _highContrast = prefs.getBool('highContrast') ?? false;
    notifyListeners();
  }

  Future<void> toggleHighContrast() async {
    _highContrast = !_highContrast;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('highContrast', _highContrast);
    notifyListeners();
  }
}
