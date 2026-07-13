import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';
import 'prefs.dart';
import 'recents.dart';
import 'server.dart';
import 'strings.dart';
import 'thumbs.dart';
import 'viewer_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();
const _channel = MethodChannel('geunyang/native');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  await Thumbs.init();
  await LocalServer.start();
  runApp(const GeunyangApp());
}

/// 파일을 뷰어로 연다. 어디서 호출하든 최근 목록에도 기록.
/// 뷰어가 닫힐 때까지 완료되지 않는다 — 호출부가 await 후 목록을 갱신하면
/// 뷰어에서 바뀐 고정 상태 등이 반영된다.
Future<void> openFile(BuildContext? context, String path) async {
  await Recents.add(path);
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  await nav.push(MaterialPageRoute(builder: (_) => ViewerScreen(filePath: path)));
}

class GeunyangApp extends StatefulWidget {
  const GeunyangApp({super.key});

  @override
  State<GeunyangApp> createState() => _GeunyangAppState();
}

class _GeunyangAppState extends State<GeunyangApp> {
  @override
  void initState() {
    super.initState();
    // 다른 앱에서 "연결 프로그램 → 그냥 리더"로 넘어온 파일 처리
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openFile') {
        final path = call.arguments as String?;
        if (path != null) openFile(null, path);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final path = await _channel.invokeMethod<String>('getInitialFile');
        if (path != null) openFile(null, path);
      } on MissingPluginException {
        // iOS: 네이티브 채널 미구현 — 파일 앱 연동은 추후
      }
    });
  }

  ThemeData _theme(Brightness b, {bool sepia = false}) {
    // 차분한 웜 그레이 팔레트 + 명조 타이틀. 세피아는 따뜻한 종이 톤.
    final cs = ColorScheme.fromSeed(
      seedColor: sepia ? const Color(0xFF8A6D3B) : const Color(0xFF7D6F5E),
      brightness: b,
    ).copyWith(
      surface: sepia ? const Color(0xFFF4ECD8) : null,
      onSurface: sepia ? const Color(0xFF4B3F2F) : null,
    );
    final bg = sepia
        ? const Color(0xFFEDE4CE)
        : (b == Brightness.light ? const Color(0xFFF7F5F1) : null);
    return ThemeData(
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: bg,
        titleTextStyle: TextStyle(
          fontFamily: 'GowunBatang',
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Prefs.revision,
      builder: (context, child) => MaterialApp(
        title: S.appName,
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light, sepia: Prefs.themeMode == 'sepia'),
        darkTheme: _theme(Brightness.dark),
        themeMode: switch (Prefs.themeMode) {
          'light' || 'sepia' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        home: const HomeScreen(),
      ),
    );
  }
}
