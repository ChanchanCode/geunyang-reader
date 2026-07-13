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

/// 고정한 문서. 최근 목록과 달리 개수 제한·자동 삭제가 없다 — 사용자가 뺄 때까지 유지.
class Favorites {
  static const _key = 'favorite_files';

  /// 고정한 순서(최신 먼저)대로, 존재하는 파일만.
  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null) return [];
    return raw.where((p) => File(p).existsSync()).toList();
  }

  static Future<bool> contains(String path) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.contains(path) ?? false;
  }

  /// 고정/해제 토글. 새 결과(고정 여부)를 반환.
  static Future<bool> toggle(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    final was = list.remove(path);
    if (!was) list.insert(0, path);
    await prefs.setStringList(_key, list);
    return !was;
  }

  static Future<void> remove(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(path);
    await prefs.setStringList(_key, list);
  }
}
