import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/discharge_profile.dart';

const _kProfile = 'dd214_profile';
const _kDone = 'dd214_done';

/// The one source of truth for "who is this veteran" across all tabs.
/// Stores only parsed fields, never the photo or raw OCR text.
class AppState extends ChangeNotifier {
  DischargeProfile? _profile;
  final Set<String> _done = {};
  bool _loaded = false;

  DischargeProfile? get profile => _profile;
  Set<String> get done => _done;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kProfile);
      if (raw != null) {
        _profile = DischargeProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _done.addAll(prefs.getStringList(_kDone) ?? const []);
      }
    } catch (e) {
      debugPrint('AppState load failed, starting fresh: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> saveProfile(DischargeProfile p) async {
    _profile = p;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfile, jsonEncode(p.toJson()));
  }

  Future<void> toggle(String id, bool value) async {
    value ? _done.add(id) : _done.remove(id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kDone, _done.toList());
  }

  Future<void> reset() async {
    _profile = null;
    _done.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProfile);
    await prefs.remove(_kDone);
  }
}
