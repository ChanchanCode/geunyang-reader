import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전역 설정. 값이 바뀌면 [revision]이 올라가고 MaterialApp이 다시 빌드된다.
class Prefs {
  static late SharedPreferences _p;
  static final ValueNotifier<int> revision = ValueNotifier(0);

  /// 뷰어 밝기 전용 알림. 이 값은 앱 전체가 아니라 뷰어 오버레이만 다시 그린다.
  static final ValueNotifier<double> brightnessNotifier = ValueNotifier(1.0);

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    brightnessNotifier.value = brightness;
  }

  static void _bump() => revision.value++;

  /// 'system' | 'ko' | 'en'
  static String get lang => _p.getString('lang') ?? 'system';
  static set lang(String v) {
    _p.setString('lang', v);
    _bump();
  }

  /// 'system' | 'light' | 'dark' | 'sepia'
  static String get themeMode => _p.getString('themeMode') ?? 'system';
  static set themeMode(String v) {
    _p.setString('themeMode', v);
    _bump();
  }

  /// 뷰어 화면 밝기(0.2~1.0). 1.0이면 어둡게 덮지 않음.
  /// 앱 전체 리빌드를 유발하지 않도록 [_bump] 대신 [brightnessNotifier]만 갱신한다.
  static double get brightness => _p.getDouble('brightness') ?? 1.0;
  static set brightness(double v) {
    final c = v.clamp(0.2, 1.0);
    _p.setDouble('brightness', c);
    brightnessNotifier.value = c;
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

  // ---- 문서별 줌 배율 기억 (docx·pptx·hwp·xlsx·md·txt) ----
  static double? zoom(String key) => _p.getDouble('zoom:$key');
  static void saveZoom(String key, double scale) =>
      _p.setDouble('zoom:$key', scale);

  // ---- epub 읽던 위치 (CFI+scrollTop JSON). 뷰어가 localStorage에 저장하면
  // 서버 포트가 매 실행 바뀌어 소실되므로, JS 브리지로 여기(경로+크기 키)에 저장한다. ----
  static String? epubPos(String key) => _p.getString('epub:$key');
  static void saveEpubPos(String key, String json) =>
      _p.setString('epub:$key', json);
}
