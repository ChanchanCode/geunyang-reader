import 'package:flutter/material.dart';

/// 지원 포맷 정의: 확장자 → 뷰어 페이지 매핑.
class Formats {
  /// 이미지 — img.html이 렌더
  static const Set<String> image = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg',
  };

  /// 코드·설정 등 일반 텍스트 — txt.html이 그대로 렌더
  static const Set<String> code = {
    'json', 'xml', 'yaml', 'yml', 'ini', 'toml', 'conf', 'properties',
    'py', 'js', 'ts', 'tsx', 'jsx', 'java', 'kt', 'kts', 'gradle',
    'c', 'h', 'cpp', 'cc', 'hpp', 'cs', 'go', 'rs', 'rb', 'php',
    'sh', 'bash', 'sql', 'css', 'scss', 'dart',
  };

  static const Set<String> supported = {
    'pdf',
    'docx',
    'pptx',
    'hwp', 'hwpx',
    'html', 'htm',
    'md', 'markdown',
    'txt', 'log',
    'xlsx', 'xls', 'csv',
    'epub',
    ...image,
    ...code,
  };

  static String ext(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  static bool isSupported(String path) => supported.contains(ext(path));

  /// 페이지 모드(스와이프 넘김)를 지원하는 포맷 (txt 뷰어로 열리는 것 포함)
  static bool supportsPageMode(String path) {
    final e = ext(path);
    return const {'pdf', 'epub', 'md', 'markdown', 'txt', 'log'}.contains(e) ||
        code.contains(e);
  }

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

    if (image.contains(e)) return page('img.html');
    if (code.contains(e)) return page('txt.html');

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
      case 'pptx':
        return page('pptx.html');
      case 'hwp':
      case 'hwpx':
        // 둘 다 rhwp(WASM)가 렌더링한다
        return page('hwp.html');
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
    final e = ext(path);
    if (image.contains(e)) return Icons.image_outlined;
    if (code.contains(e)) return Icons.code_outlined;
    switch (e) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'docx':
        return Icons.description_outlined;
      case 'pptx':
        return Icons.slideshow_outlined;
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

  /// 확장자별 저채도 배지 색 — 알록달록하지 않게, 편안한 톤으로
  static Color color(String path) {
    final e = ext(path);
    if (image.contains(e)) return const Color(0xFF7FA0A8); // 뮤트 스틸블루
    if (code.contains(e)) return const Color(0xFF8B8F98); // 그레이
    switch (e) {
      case 'pdf':
        return const Color(0xFFB56A5E); // 테라코타
      case 'docx':
        return const Color(0xFF6E86C0); // 뮤트 블루
      case 'pptx':
        return const Color(0xFFC08A5E); // 뮤트 오렌지
      case 'hwp':
      case 'hwpx':
        return const Color(0xFF64949E); // 뮤트 청록
      case 'xlsx':
      case 'xls':
      case 'csv':
        return const Color(0xFF7BA57C); // 세이지
      case 'epub':
        return const Color(0xFF9C82AE); // 뮤트 퍼플
      case 'html':
      case 'htm':
        return const Color(0xFFBFA05F); // 뮤트 앰버
      default:
        return const Color(0xFF8B8F98); // 그레이 (md, txt 등)
    }
  }

  /// 배지에 쓰는 짧은 라벨
  static String badge(String path) {
    final e = ext(path);
    if (image.contains(e)) return 'IMG';
    if (code.contains(e)) return e.length <= 4 ? e.toUpperCase() : 'CODE';
    switch (e) {
      case 'pdf':
        return 'PDF';
      case 'docx':
        return 'DOC';
      case 'pptx':
        return 'PPT';
      case 'hwp':
      case 'hwpx':
        return 'HWP';
      case 'xlsx':
      case 'xls':
        return 'XLS';
      case 'csv':
        return 'CSV';
      case 'epub':
        return 'EPUB';
      case 'md':
      case 'markdown':
        return 'MD';
      case 'html':
      case 'htm':
        return 'HTML';
      default:
        return 'TXT';
    }
  }
}
