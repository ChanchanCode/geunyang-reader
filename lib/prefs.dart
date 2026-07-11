import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전역 설정. 값이 바뀌면 [revision]이 올라가고 MaterialApp이 다시 빌드된다.
class Prefs {
  static late SharedPreferences _p;
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  static void _bump() => revision.value++;

  /// 'system' | 'ko' | 'en'
  static String get lang => _p.getString('lang') ?? 'system';
  static set lang(String v) {
    _p.setString('lang', v);
    _bump();
  }

  /// 'system' | 'light' | 'dark'
  static String get themeMode => _p.getString('themeMode') ?? 'system';
  static set themeMode(String v) {
    _p.setString('themeMode', v);
    _bump();
  }

  /// md·txt 본문 글자 크기(px)
  static double get fontSize => _p.getDouble('fontSize') ?? 16;
  static set fontSize(double v) {
    _p.setDouble('fontSize', v);
    _bump();
  }

  /// md·txt 줄 간격 배수
  static double get lineHeight => _p.getDouble('lineHeight') ?? 1.65;
  static set lineHeight(double v) {
    _p.setDouble('lineHeight', v);
    _bump();
  }

  /// 'scroll' | 'page' — pdf·epub·md·txt에만 적용
  static String get pageMode => _p.getString('pageMode') ?? 'scroll';
  static set pageMode(String v) {
    _p.setString('pageMode', v);
    _bump();
  }

  /// 문서 보는 동안 화면 꺼짐 방지
  static bool get keepScreenOn => _p.getBool('keepScreenOn') ?? false;
  static set keepScreenOn(bool v) {
    _p.setBool('keepScreenOn', v);
    _bump();
  }

  // ---- 읽던 위치 기억 ----
  static ({double x, double y})? position(String key) {
    final x = _p.getDouble('posx:$key');
    final y = _p.getDouble('posy:$key');
    if (x == null || y == null) return null;
    return (x: x, y: y);
  }

  static void savePosition(String key, double x, double y) {
    _p.setDouble('posx:$key', x);
    _p.setDouble('posy:$key', y);
  }
}
