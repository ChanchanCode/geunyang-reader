import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'formats.dart';
import 'server.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.filePath});
  final String filePath;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  String get _name => widget.filePath.split('/').last;

  @override
  Widget build(BuildContext context) {
    final server = LocalServer.instance!;
    final url = Formats.viewerUrl(server.origin, server.token, widget.filePath);
    return Scaffold(
      appBar: AppBar(
        title: Text(_name, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
        toolbarHeight: 48,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
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
