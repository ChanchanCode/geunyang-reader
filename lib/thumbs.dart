import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'formats.dart';

/// 문서 썸네일 캐시 — 뷰어가 문서를 그린 뒤 찍은 스크린샷을 보관한다.
/// (별도 렌더러 없이 전 포맷을 커버하는 가장 싼 방법. 한 번 연 파일에만 생긴다.)
class Thumbs {
  static Directory? _dir;

  static Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final cache = await getApplicationCacheDirectory();
    _dir = Directory('${cache.path}/thumbs');
    if (!_dir!.existsSync()) _dir!.createSync(recursive: true);
    return _dir!;
  }

  /// 파일 내용이 바뀌면 키도 바뀌게 경로+크기+수정시각으로 키를 만든다.
  static String _key(String path) {
    int size = 0, mtime = 0;
    try {
      final st = File(path).statSync();
      size = st.size;
      mtime = st.modified.millisecondsSinceEpoch ~/ 1000;
    } catch (_) {}
    return '${path.hashCode.toRadixString(16)}-$size-$mtime.jpg';
  }

  static Future<File> fileFor(String docPath) async {
    final dir = await _ensureDir();
    return File('${dir.path}/${_key(docPath)}');
  }

  /// 있으면 썸네일 파일, 없으면 null (동기 — 목록 빌드용)
  static File? existing(String docPath) {
    final dir = _dir;
    if (dir == null) return null;
    final f = File('${dir.path}/${_key(docPath)}');
    return f.existsSync() ? f : null;
  }

  /// 앱 시작 시 한 번 불러 캐시 디렉토리를 준비해 둔다.
  static Future<void> init() => _ensureDir();
}

/// 파일 목록용 미리보기: 썸네일이 있으면 문서 첫 화면, 없으면 포맷 아이콘
class DocThumb extends StatelessWidget {
  const DocThumb({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final f = Thumbs.existing(path);
    if (f == null) return Icon(Formats.icon(path));
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        f,
        width: 38,
        height: 50,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (_, e, st) => Icon(Formats.icon(path)),
      ),
    );
  }
}
