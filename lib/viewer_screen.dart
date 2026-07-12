import 'dart:async';
import 'dart:convert';
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

  double _htmlZoom = 1.0; // 안드로이드에서 현재 적용된 페이지 줌 (재계산용)

  /// 모바일 대응이 안 된 HTML(뷰포트 없음/고정폭)은 좌우가 잘린다.
  /// 폭 계산은 scrollWidth(오른쪽 최대)만 보면 안 된다 — 가운데 정렬된 고정폭 블록은
  /// 왼쪽(음수 좌표)으로 삐져나가고, 그 영역은 스크롤로 도달 불가.
  /// 그래서 "전체 요소"의 bounding box로 좌우 경계를 재고, 왼쪽으로 나간 만큼
  /// 본문을 밀어 넣은 뒤 전체 폭 기준으로 맞춘다. 지연 로드(이미지 등)로 폭이
  /// 바뀔 수 있어 몇 차례 재계산한다.
  Future<void> _fitRawHtml(InAppWebViewController c) async {
    const measureJs = '''(function () {
      if (!window.__gyStyle) {
        window.__gyStyle = document.createElement('style');
        __gyStyle.textContent =
          'img, video, iframe { max-width: 100% !important; height: auto !important; }';
        (document.head || document.documentElement).appendChild(__gyStyle);
      }
      var body = document.body, doc = document.documentElement;
      if (!body) return JSON.stringify({ w: 0, dw: 1 });
      body.style.marginLeft = '';
      var sx = window.scrollX;
      var minL = 0;
      var maxR = Math.max(doc.scrollWidth, body.scrollWidth);
      var els = body.getElementsByTagName('*');
      for (var i = 0; i < els.length; i++) {
        var r = els[i].getBoundingClientRect();
        if (!r.width && !r.height) continue;
        if (r.left + sx < minL) minL = r.left + sx;
        if (r.right + sx > maxR) maxR = r.right + sx;
      }
      if (minL < -1) {
        // 왼쪽으로 삐져나간 만큼 오른쪽으로 밀어 스크롤 가능한 영역 [0, w]로 만든다
        body.style.marginLeft = (-minL) + 'px';
        maxR += -minL;
      }
      var dw = Math.min(screen.width, window.innerWidth) || screen.width;
      var mv = document.querySelector('meta[name="viewport"]');
      if (!mv) {
        mv = document.createElement('meta');
        mv.setAttribute('name', 'viewport');
        (document.head || document.documentElement).appendChild(mv);
      }
      mv.setAttribute('content', (maxR > dw * 1.05)
        ? 'width=' + Math.ceil(maxR) + ', user-scalable=yes, minimum-scale=0.05, maximum-scale=10'
        : 'width=device-width, initial-scale=1, user-scalable=yes, maximum-scale=10');
      return JSON.stringify({ w: Math.ceil(maxR), dw: dw });
    })();''';

    Future<void> applyOnce() async {
      final res = await _web?.evaluateJavascript(source: measureJs);
      if (res == null) return;
      final m = res is String
          ? Map<String, dynamic>.from(jsonDecode(res) as Map)
          : Map<String, dynamic>.from(res as Map);
      final w = (m['w'] as num?)?.toDouble() ?? 0;
      final dw = (m['dw'] as num?)?.toDouble() ?? 1;
      if (w <= 0 || dw <= 0) return;
      if (Platform.isAndroid) {
        // 안드로이드는 늦은 뷰포트 변경을 무시하므로 페이지 줌으로 맞춘다
        final target = w > dw * 1.05 ? dw / w : 1.0;
        if ((target - _htmlZoom).abs() > 0.02) {
          try {
            await _web?.zoomBy(zoomFactor: target / _htmlZoom, animated: false);
            _htmlZoom = target;
          } catch (_) {}
        }
      }
    }

    await applyOnce();
    // 이미지 지연 로드 등으로 폭이 바뀌는 경우 재계산
    for (final delay in const [1200, 3500]) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) applyOnce();
      });
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
