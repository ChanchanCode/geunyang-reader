import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'formats.dart';
import 'prefs.dart';
import 'recents.dart';
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
  bool _fav = false;
  bool _immersive = false;

  // 문서별 줌 배율 (안드로이드 네이티브 WebView 줌)
  double? _savedZoom;
  double _curScale = 1.0;
  Timer? _zoomSaver;

  // 로딩/실패 표시 (raw html은 자체 스피너가 없어 Flutter 레벨에서 처리)
  bool _loading = false;
  bool _loadError = false;
  Timer? _loadWatchdog;

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

  /// 줌 배율 기억: 안드로이드 네이티브 줌을 쓰는 문서만.
  /// raw html은 자체 폭 맞춤(_htmlZoom)과 충돌하고, pdf·epub은 자체 뷰어가 처리한다.
  bool get _remembersZoom =>
      Platform.isAndroid &&
      !_isRawHtml &&
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
    if (_remembersZoom) _savedZoom = Prefs.zoom(_posKey);
    // raw html은 페이지 내 스피너가 없어 로딩 표시를 Flutter가 담당
    _loading = _isRawHtml;
    if (_loading) {
      _loadWatchdog = Timer(const Duration(seconds: 25), () {
        if (mounted) setState(() => _loading = false);
      });
    }
    Favorites.contains(widget.filePath).then((v) {
      if (mounted) setState(() => _fav = v);
    });
  }

  void _restoreZoom() {
    final s = _savedZoom;
    if (!_remembersZoom || s == null || s <= 0) return;
    // 렌더가 안정된 뒤 배율 적용 (위치 복원과 같은 다단계 재시도)
    for (final delay in const [500, 1500]) {
      Future.delayed(Duration(milliseconds: delay), () async {
        if (!mounted) return;
        final cur = _curScale <= 0 ? 1.0 : _curScale;
        final factor = s / cur;
        if ((factor - 1).abs() < 0.03) return;
        try {
          await _web?.zoomBy(zoomFactor: factor, animated: false);
        } catch (_) {}
      });
    }
  }

  Future<void> _toggleFav() async {
    final now = await Favorites.toggle(widget.filePath);
    if (!mounted) return;
    setState(() => _fav = now);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(now ? S.pinAdded : S.pinRemoved),
      duration: const Duration(seconds: 1),
    ));
  }

  /// 밝기 조절 시트 — 화면을 어둡게 덮는 오버레이 세기를 조절한다.
  void _brightnessSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.brightness_low, size: 20),
                Expanded(
                  child: Slider(
                    value: Prefs.brightness,
                    min: 0.2,
                    max: 1.0,
                    onChanged: (v) => setSheet(() => Prefs.brightness = v),
                  ),
                ),
                const Icon(Icons.brightness_high, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _posSaver?.cancel();
    _zoomSaver?.cancel();
    _loadWatchdog?.cancel();
    WakelockPlus.disable();
    if (_immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _viewerOpts(BuildContext context) {
    final dark = Prefs.themeMode == 'dark' ||
        (Prefs.themeMode == 'system' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final th = Prefs.themeMode == 'sepia' ? 'sepia' : (dark ? 'dark' : 'light');
    // epub은 바깥 웹뷰가 스크롤하지 않아 위치를 JS 브리지로 저장한다.
    // 저장해 둔 위치가 있으면 뷰어에 넘겨 그 지점부터 열게 한다.
    String epos = '';
    if (Formats.ext(widget.filePath) == 'epub') {
      final saved = Prefs.epubPos(_posKey);
      if (saved != null) epos = Uri.encodeComponent(saved);
    }
    return {
      'fs': Prefs.fontSize.round().toString(),
      'lh': Prefs.lineHeight.toStringAsFixed(2),
      'th': th,
      if (epos.isNotEmpty) 'epos': epos,
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

  /// 다른 앱으로 '보기'(ACTION_VIEW) — 공유가 아니라 편집기 등으로 넘김
  Future<void> _openWith() async {
    try {
      await _channel.invokeMethod('openWith', {'path': widget.filePath});
    } catch (_) {}
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(S.deleteConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(S.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(S.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await File(widget.filePath).delete();
      await Recents.remove(widget.filePath);
      await Favorites.remove(widget.filePath);
      if (mounted) Navigator.pop(context); // 뷰어 닫기 → 호출부가 목록 갱신
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.deleteFailed)));
      }
    }
  }

  /// 몰입(전체화면) 읽기 토글 — 앱바·시스템바 숨김
  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
    SystemChrome.setEnabledSystemUIMode(
        _immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  /// 본문 가운데를 탭하면 몰입 토글. 링크·버튼·선택·가장자리(페이지넘김/툴바)는 제외.
  static const String _tapToggleJs = '''(function(){
    if (window.__gyTap) return; window.__gyTap = 1;
    document.addEventListener('click', function(e){
      var t = e.target;
      if (t && t.closest && t.closest('a,button,input,select,textarea,label,[contenteditable],[role=button]')) return;
      var s = window.getSelection && window.getSelection();
      if (s && String(s).length) return;
      var w = window.innerWidth || 360, h = window.innerHeight || 640;
      if (e.clientX < w*0.25 || e.clientX > w*0.75) return;
      if (e.clientY < h*0.12 || e.clientY > h*0.90) return;
      try { window.flutter_inappwebview.callHandler('tapToggle'); } catch(_){}
    }, true);
  })();''';

  @override
  Widget build(BuildContext context) {
    final server = LocalServer.instance!;
    final url = Formats.viewerUrl(
        server.origin, server.token, widget.filePath, _viewerOpts(context));
    return Scaffold(
      appBar: _immersive
          ? null
          : AppBar(
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
                    icon: Icon(_fav ? Icons.push_pin : Icons.push_pin_outlined),
                    tooltip: S.pinned,
                    onPressed: _toggleFav),
                IconButton(
                    icon: const Icon(Icons.brightness_medium_outlined),
                    tooltip: S.brightness,
                    onPressed: _brightnessSheet),
                IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: S.share,
                    onPressed: _share),
                PopupMenuButton<String>(
                  onSelected: (v) =>
                      v == 'open' ? _openWith() : _confirmDelete(),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'open',
                      child: Row(children: [
                        const Icon(Icons.open_in_new, size: 20),
                        const SizedBox(width: 12),
                        Text(S.openWith),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            size: 20, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 12),
                        Text(S.delete),
                      ]),
                    ),
                  ],
                ),
              ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        findInteractionController: _find,
        initialUserScripts: UnmodifiableListView([
          UserScript(
              source: _tapToggleJs,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END),
        ]),
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
        onWebViewCreated: (c) {
          _web = c;
          // epub 뷰어가 읽던 위치(CFI+scrollTop)를 넘겨주면 경로 키로 저장
          c.addJavaScriptHandler(
            handlerName: 'saveEpubPos',
            callback: (args) {
              if (args.isNotEmpty && args.first is String) {
                Prefs.saveEpubPos(_posKey, args.first as String);
              }
            },
          );
          // 본문 가운데 탭 → 몰입 모드 토글
          c.addJavaScriptHandler(
            handlerName: 'tapToggle',
            callback: (args) {
              if (!_searching) _toggleImmersive();
            },
          );
        },
        onLoadStop: (c, u) async {
          _loadWatchdog?.cancel();
          if (mounted && _loading) setState(() => _loading = false);
          if (_isRawHtml) await _fitRawHtml(c);
          _restorePosition();
          _restoreZoom();
          _captureThumb(c);
        },
        onReceivedError: (c, req, err) {
          // 메인 프레임 로드 실패만 폴백 화면으로 (하위 리소스 오류는 무시)
          if (req.isForMainFrame != true) return;
          if (mounted) {
            setState(() {
              _loading = false;
              _loadError = true;
            });
          }
        },
        onZoomScaleChanged: (c, oldScale, newScale) {
          _curScale = newScale;
          if (!_remembersZoom) return;
          _zoomSaver?.cancel();
          _zoomSaver = Timer(const Duration(milliseconds: 400), () {
            Prefs.saveZoom(_posKey, newScale);
          });
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
            // 밝기 오버레이 — 앱 전체가 아니라 이 부분만 다시 그린다
            ValueListenableBuilder<double>(
              valueListenable: Prefs.brightnessNotifier,
              builder: (_, b, child) => b >= 1.0
                  ? const SizedBox.shrink()
                  : Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.black
                              .withValues(alpha: (1.0 - b) * 0.75),
                        ),
                      ),
                    ),
            ),
            if (_loading)
              Positioned.fill(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            if (_loadError) Positioned.fill(child: _errorPanel(context)),
          ],
        ),
      ),
    );
  }

  Widget _errorPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 44, color: cs.outline),
          const SizedBox(height: 16),
          Text(S.cantOpenFile,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(S.cantOpenBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.outline, height: 1.5)),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: _openWith,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(S.openWith),
          ),
        ],
      ),
    );
  }
}
