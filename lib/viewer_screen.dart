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
      body: InAppWebView(
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
        onLoadStop: (c, u) => _restorePosition(),
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
    );
  }
}
