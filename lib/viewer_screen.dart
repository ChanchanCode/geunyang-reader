import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'formats.dart';
import 'prefs.dart';
import 'server.dart';
import 'strings.dart';
import 'thumbs.dart';

const _channel = MethodChannel('geunyang/native');

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.filePath});
  final String filePath;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  InAppWebViewController? _web;
  late final FindInteractionController _find;
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  int _matchIdx = 0;
  int _matchCount = 0;
  Timer? _posSaver;

  String get _name => widget.filePath.split('/').last;

  /// 읽던 위치 키: 경로 + 크기 (파일이 바뀌면 위치 무효화)
  String get _posKey {
    int size = 0;
    try {
      size = File(widget.filePath).lengthSync();
    } catch (_) {}
    return '${widget.filePath}:$size';
  }

  /// pdf는 pdf.js가, epub은 스크롤 구조가 달라 자체 처리 — 나머지만 위치 기억
  bool get _remembersPosition =>
      !const {'pdf', 'epub'}.contains(Formats.ext(widget.filePath));

  /// 뷰어 래퍼 없이 원본 그대로 여는 포맷 (html)
  bool get _isRawHtml =>
      const {'html', 'htm'}.contains(Formats.ext(widget.filePath));

  /// 모바일 대응이 안 된 HTML(뷰포트 없음/고정폭)은 좌우가 잘린다.
  /// 1) 뷰포트를 실제 콘텐츠 폭에 맞추고 핀치 줌을 강제 허용 (iOS에서 유효)
  /// 2) 고정폭 미디어는 화면 폭에 맞춤
  /// 3) 그래도 넘치면 페이지 줌으로 축소 (안드로이드는 늦은 뷰포트 변경을 무시해서)
  Future<void> _fitRawHtml(InAppWebViewController c) async {
    await c.evaluateJavascript(source: '''(function () {
      var dw = Math.min(screen.width, window.innerWidth) || screen.width;
      var w = Math.max(document.documentElement.scrollWidth,
                       document.body ? document.body.scrollWidth : 0);
      var mv = document.querySelector('meta[name="viewport"]');
      if (!mv) {
        mv = document.createElement('meta');
        mv.setAttribute('name', 'viewport');
        (document.head || document.documentElement).appendChild(mv);
      }
      mv.setAttribute('content', (w > dw * 1.05)
        ? 'width=' + w + ', user-scalable=yes, minimum-scale=0.05, maximum-scale=10'
        : 'width=device-width, initial-scale=1, user-scalable=yes, maximum-scale=10');
      var st = document.createElement('style');
      st.textContent = 'img, video, iframe { max-width: 100% !important; height: auto !important; }';
      (document.head || document.documentElement).appendChild(st);
    })();''');
    if (Platform.isAndroid) {
      await Future.delayed(const Duration(milliseconds: 300));
      final ratio = await _web?.evaluateJavascript(
          source:
              'Math.max(document.documentElement.scrollWidth, document.body ? document.body.scrollWidth : 0)'
              ' / Math.max(1, Math.min(screen.width, window.innerWidth))');
      final r = (ratio is num) ? ratio.toDouble() : 1.0;
      if (r > 1.05) {
        try {
          await _web?.zoomBy(zoomFactor: 1 / r, animated: false);
        } catch (_) {}
      }
    }
  }

  /// 문서가 그려진 뒤 스크린샷을 썸네일로 저장 (파일 목록에서 미리보기용)
  Future<void> _captureThumb(InAppWebViewController c) async {
    try {
      final f = await Thumbs.fileFor(widget.filePath);
      if (f.existsSync()) return;
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return;
      final bytes = await c.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          compressFormat: CompressFormat.JPEG,
          quality: 55,
        ),
      );
      if (bytes != null && bytes.isNotEmpty) await f.writeAsBytes(bytes);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _find = FindInteractionController(
      onFindResultReceived: (c, activeIdx, count, done) {
        if (done && mounted) {
          setState(() {
            _matchIdx = count == 0 ? 0 : activeIdx + 1;
            _matchCount = count;
          });
        }
      },
    );
    if (Prefs.keepScreenOn) WakelockPlus.enable();
  }

  @override
  void dispose() {
    _posSaver?.cancel();
    WakelockPlus.disable();
    _searchCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _viewerOpts(BuildContext context) {
    final dark = Prefs.themeMode == 'dark' ||
        (Prefs.themeMode == 'system' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return {
      'fs': Prefs.fontSize.round().toString(),
      'lh': Prefs.lineHeight.toStringAsFixed(2),
      'th': dark ? 'dark' : 'light',
      'pm': Formats.supportsPageMode(widget.filePath) ? Prefs.pageMode : 'scroll',
      'lang': S.ko ? 'ko' : 'en',
    };
  }

  void _restorePosition() {
    if (!_remembersPosition) return;
    final pos = Prefs.position(_posKey);
    if (pos == null || (pos.x == 0 && pos.y == 0)) return;
    // 렌더러가 비동기로 그리므로 몇 차례에 나눠 복원 시도
    for (final delay in const [400, 1200, 2500]) {
      Future.delayed(Duration(milliseconds: delay), () {
        _web?.scrollTo(x: pos.x.round(), y: pos.y.round(), animated: false);
      });
    }
  }

  void _startSearch() {
    setState(() {
      _searching = true;
      _matchIdx = 0;
      _matchCount = 0;
    });
  }

  void _stopSearch() {
    _find.clearMatches();
    _searchCtrl.clear();
    setState(() => _searching = false);
  }

  Future<void> _share() async {
    try {
      await _channel.invokeMethod('shareFile', {'path': widget.filePath});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final server = LocalServer.instance!;
    final url = Formats.viewerUrl(
        server.origin, server.token, widget.filePath, _viewerOpts(context));
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: S.search,
                  border: InputBorder.none,
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  if (v.isNotEmpty) _find.findAll(find: v);
                },
              )
            : Text(_name,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis),
        actions: _searching
            ? [
                if (_matchCount > 0)
                  Center(
                      child: Text('$_matchIdx/$_matchCount',
                          style: const TextStyle(fontSize: 13))),
                IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: () => _find.findNext(forward: false)),
                IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => _find.findNext(forward: true)),
                IconButton(icon: const Icon(Icons.close), onPressed: _stopSearch),
              ]
            : [
                IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: S.search,
                    onPressed: _startSearch),
                IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: S.share,
                    onPressed: _share),
              ],
      ),
      body: SafeArea(
        top: false,
        child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        findInteractionController: _find,
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          supportZoom: true,
          builtInZoomControls: true,
          displayZoomControls: false,
          useWideViewPort: true,
          loadWithOverviewMode: true,
          allowFileAccess: false,
          allowFileAccessFromFileURLs: false,
          allowUniversalAccessFromFileURLs: false,
          useShouldOverrideUrlLoading: true,
          verticalScrollBarEnabled: true,
          horizontalScrollBarEnabled: true,
          transparentBackground: false,
        ),
        onWebViewCreated: (c) => _web = c,
        onLoadStop: (c, u) async {
          if (_isRawHtml) await _fitRawHtml(c);
          _restorePosition();
          _captureThumb(c);
        },
        onScrollChanged: (c, x, y) {
          if (!_remembersPosition) return;
          _posSaver?.cancel();
          _posSaver = Timer(const Duration(milliseconds: 300), () {
            Prefs.savePosition(_posKey, x.toDouble(), y.toDouble());
          });
        },
        shouldOverrideUrlLoading: (controller, action) async {
          final uri = action.request.url;
          if (uri == null) return NavigationActionPolicy.CANCEL;
          // 로컬 서버 내 이동은 허용, 외부 링크는 기본 브라우저로
          if (uri.host == '127.0.0.1') return NavigationActionPolicy.ALLOW;
          if (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'mailto') {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          return NavigationActionPolicy.CANCEL;
        },
        ),
      ),
    );
  }
}
