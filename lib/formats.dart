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

  /// 파일 경로 → 로컬 서버 뷰어 URL. [origin]은 http://127.0.0.1:port, [token]은 서버 토큰.
  static String viewerUrl(String origin, String token, String filePath) {
    final e = ext(filePath);
    final fsPath =
        filePath.split('/').map(Uri.encodeComponent).join('/');
    final docUrl = '/$token/fs$fsPath';
    final name = Uri.encodeComponent(filePath.split('/').last);

    switch (e) {
      case 'pdf':
        return '$origin/$token/assets/pdfjs/web/viewer.html'
            '?file=${Uri.encodeComponent(docUrl)}';
      case 'html':
      case 'htm':
        return '$origin$docUrl';
      case 'md':
      case 'markdown':
        return '$origin/$token/assets/md.html?doc=${Uri.encodeComponent(docUrl)}&name=$name';
      case 'txt':
      case 'log':
        return '$origin/$token/assets/txt.html?doc=${Uri.encodeComponent(docUrl)}&name=$name';
      case 'docx':
        return '$origin/$token/assets/docx.html?doc=${Uri.encodeComponent(docUrl)}&name=$name';
      case 'hwp':
        return '$origin/$token/assets/hwp.html?doc=${Uri.encodeComponent(docUrl)}&name=$name';
      case 'hwpx':
        return '$origin/$token/assets/hwpx.html?doc=${Uri.encodeComponent(docUrl)}&name=$name';
      case 'xlsx':
      case 'xls':
      case 'csv':
        return '$origin/$token/assets/xlsx.html?doc=${Uri.encodeComponent(docUrl)}&name=$name';
      case 'epub':
        return '$origin/$token/assets/epub.html?doc=${Uri.encodeComponent(docUrl)}&name=$name';
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
