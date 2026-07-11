import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

/// 루프백 전용 HTTP 서버.
/// - /{token}/assets/...  → 번들된 뷰어 자산 (assets/viewer/)
/// - /{token}/fs/...      → 로컬 파일 (Range 지원; 대용량 PDF 스트리밍용)
/// 토큰이 없으면 다른 앱이 포트를 뚫어도 파일을 읽을 수 없다.
class LocalServer {
  LocalServer._(this._server, this.token);

  final HttpServer _server;
  final String token;

  String get origin => 'http://127.0.0.1:${_server.port}';

  static LocalServer? instance;

  static Future<LocalServer> start() async {
    if (instance != null) return instance!;
    final rand = Random.secure();
    final token =
        List.generate(16, (_) => rand.nextInt(16).toRadixString(16)).join();
    final server = HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final s = LocalServer._(await server, token);
    s._server.listen(s._handle, onError: (_) {});
    instance = s;
    return s;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final segs = req.uri.pathSegments;
      if (segs.length < 2 || segs[0] != token) {
        req.response.statusCode = HttpStatus.forbidden;
        await req.response.close();
        return;
      }
      if (segs[1] == 'assets') {
        await _serveAsset(req, segs.sublist(2).join('/'));
      } else if (segs[1] == 'fs') {
        await _serveFile(req, '/${segs.sublist(2).join('/')}');
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    } catch (_) {
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serveAsset(HttpRequest req, String rel) async {
    try {
      final data = await rootBundle.load('assets/viewer/$rel');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      req.response.headers.contentType = _contentType(rel);
      req.response.headers.set('Cache-Control', 'no-store');
      req.response.contentLength = bytes.length;
      req.response.add(bytes);
      await req.response.close();
    } catch (_) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    }
  }

  Future<void> _serveFile(HttpRequest req, String path) async {
    final file = File(path);
    if (!await file.exists()) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    final len = await file.length();
    final res = req.response;
    res.headers.contentType = _contentType(path);
    res.headers.set('Accept-Ranges', 'bytes');
    res.headers.set('Cache-Control', 'no-store');

    final range = req.headers.value(HttpHeaders.rangeHeader);
    final m = range == null ? null : RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
    if (m != null && (m.group(1)!.isNotEmpty || m.group(2)!.isNotEmpty)) {
      int start, end;
      if (m.group(1)!.isEmpty) {
        // suffix range: 마지막 N바이트
        final n = int.parse(m.group(2)!);
        start = len - n < 0 ? 0 : len - n;
        end = len - 1;
      } else {
        start = int.parse(m.group(1)!);
        end = m.group(2)!.isEmpty ? len - 1 : int.parse(m.group(2)!);
      }
      if (start >= len || end < start) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        res.headers.set('Content-Range', 'bytes */$len');
        await res.close();
        return;
      }
      if (end >= len) end = len - 1;
      res.statusCode = HttpStatus.partialContent;
      res.headers.set('Content-Range', 'bytes $start-$end/$len');
      res.contentLength = end - start + 1;
      await res.addStream(file.openRead(start, end + 1));
    } else {
      res.contentLength = len;
      await res.addStream(file.openRead());
    }
    await res.close();
  }

  static ContentType _contentType(String path) {
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'html':
      case 'htm':
        return ContentType('text', 'html', charset: 'utf-8');
      case 'js':
      case 'mjs':
        return ContentType('text', 'javascript', charset: 'utf-8');
      case 'css':
        return ContentType('text', 'css', charset: 'utf-8');
      case 'json':
        return ContentType('application', 'json', charset: 'utf-8');
      case 'svg':
        return ContentType('image', 'svg+xml');
      case 'png':
        return ContentType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return ContentType('image', 'jpeg');
      case 'gif':
        return ContentType('image', 'gif');
      case 'webp':
        return ContentType('image', 'webp');
      case 'woff2':
        return ContentType('font', 'woff2');
      case 'wasm':
        return ContentType('application', 'wasm');
      case 'pdf':
        return ContentType('application', 'pdf');
      case 'txt':
      case 'md':
      case 'ftl':
      case 'log':
      case 'csv':
        return ContentType('text', 'plain', charset: 'utf-8');
      default:
        return ContentType('application', 'octet-stream');
    }
  }
}
