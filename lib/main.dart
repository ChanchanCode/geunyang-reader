import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';
import 'prefs.dart';
import 'recents.dart';
import 'server.dart';
import 'strings.dart';
import 'viewer_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();
const _channel = MethodChannel('geunyang/native');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  await LocalServer.start();
  runApp(const GeunyangApp());
}

/// 파일을 뷰어로 연다. 어디서 호출하든 최근 목록에도 기록.
Future<void> openFile(BuildContext? context, String path) async {
  await Recents.add(path);
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  nav.push(MaterialPageRoute(builder: (_) => ViewerScreen(filePath: path)));
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

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3B6EF5);
    return ListenableBuilder(
      listenable: Prefs.revision,
      builder: (context, child) => MaterialApp(
        title: S.appName,
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
          appBarTheme: const AppBarTheme(centerTitle: false),
        ),
        darkTheme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
          appBarTheme: const AppBarTheme(centerTitle: false),
        ),
        themeMode: switch (Prefs.themeMode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        home: const HomeScreen(),
      ),
    );
  }
}
