import 'package:flutter/material.dart';

/// 지원 포맷 정의: 확장자 → 뷰어 페이지 매핑.
class Formats {
  static const Set<String> supported = {
    'pdf',
    'docx',
    'hwp', 'hwpx',
    'html', 'htm',
    'md', 'markdown',
    'txt', 'log',
    'xlsx', 'xls', 'csv',
    'epub',
  };

  static String ext(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  static bool isSupported(String path) => supported.contains(ext(path));

  /// 페이지 모드(스와이프 넘김)를 지원하는 포맷
  static bool supportsPageMode(String path) =>
      const {'pdf', 'epub', 'md', 'markdown', 'txt', 'log'}.contains(ext(path));

  /// 파일 경로 → 로컬 서버 뷰어 URL. [origin]은 http://127.0.0.1:port, [token]은 서버 토큰.
  /// [opts]는 읽기 설정(fs=글자크기, lh=줄간격, th=light|dark, pm=scroll|page, lang).
  static String viewerUrl(String origin, String token, String filePath,
      Map<String, String> opts) {
    final e = ext(filePath);
    final fsPath =
        filePath.split('/').map(Uri.encodeComponent).join('/');
    final docUrl = '/$token/fs$fsPath';
    final name = Uri.encodeComponent(filePath.split('/').last);
    final q = opts.entries.map((kv) => '&${kv.key}=${kv.value}').join();

    String page(String html) =>
        '$origin/$token/assets/$html?doc=${Uri.encodeComponent(docUrl)}&name=$name$q';

    switch (e) {
      case 'pdf':
        // pdf.js는 해시 파라미터로 페이지 넘김 모드 지정 (scrollMode 3 = page)
        final hash = opts['pm'] == 'page' ? '#scrollMode=3' : '';
        return '$origin/$token/assets/pdfjs/web/viewer.html'
            '?file=${Uri.encodeComponent(docUrl)}$hash';
      case 'html':
      case 'htm':
        return '$origin$docUrl';
      case 'md':
      case 'markdown':
        return page('md.html');
      case 'txt':
      case 'log':
        return page('txt.html');
      case 'docx':
        return page('docx.html');
      case 'hwp':
        return page('hwp.html');
      case 'hwpx':
        return page('hwpx.html');
      case 'xlsx':
      case 'xls':
      case 'csv':
        return page('xlsx.html');
      case 'epub':
        return page('epub.html');
      default:
        throw ArgumentError('unsupported: $filePath');
    }
  }

  static IconData icon(String path) {
    switch (ext(path)) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'docx':
        return Icons.description_outlined;
      case 'hwp':
      case 'hwpx':
        return Icons.article_outlined;
      case 'html':
      case 'htm':
        return Icons.language_outlined;
      case 'md':
      case 'markdown':
        return Icons.notes_outlined;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return Icons.table_chart_outlined;
      case 'epub':
        return Icons.menu_book_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
