import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class RecentEntry {
  RecentEntry(this.path, this.openedAt);
  final String path;
  final DateTime openedAt;

  String get name => path.split('/').last;
}

class Recents {
  static const _key = 'recent_files';
  static const _max = 30;

  static Future<List<RecentEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => RecentEntry(
              e['path'] as String,
              DateTime.fromMillisecondsSinceEpoch(e['ts'] as int)))
          .where((e) => File(e.path).existsSync())
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await load();
    list.removeWhere((e) => e.path == path);
    list.insert(0, RecentEntry(path, DateTime.now()));
    if (list.length > _max) list.removeRange(_max, list.length);
    await prefs.setString(
        _key,
        jsonEncode([
          for (final e in list)
            {'path': e.path, 'ts': e.openedAt.millisecondsSinceEpoch}
        ]));
  }

  static Future<void> remove(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await load();
    list.removeWhere((e) => e.path == path);
    await prefs.setString(
        _key,
        jsonEncode([
          for (final e in list)
            {'path': e.path, 'ts': e.openedAt.millisecondsSinceEpoch}
        ]));
  }
}
