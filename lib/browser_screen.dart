import 'dart:io';

import 'package:flutter/material.dart';

import 'formats.dart';
import 'main.dart' show openFile;
import 'strings.dart';
import 'thumbs.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({
    super.key,
    required this.initialPath,
    this.rootPath = '/storage/emulated/0',
    this.rootLabel,
  });
  final String initialPath;
  final String rootPath; // 이 위로는 못 올라간다 (iOS는 앱 Documents)
  final String? rootLabel;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late String _path;
  List<FileSystemEntity> _entries = [];
  String? _error;
  String? _filter; // 확장자 그룹 키 (null = 폴더 보기)
  bool _collecting = false;
  int _collectGen = 0; // 필터 전환 시 이전 수집 결과 무시용

  static const _groups = <String, Set<String>>{
    'PDF': {'pdf'},
    'HWP': {'hwp', 'hwpx'},
    'Word': {'docx'},
    'Excel': {'xlsx', 'xls', 'csv'},
    'EPUB': {'epub'},
    'TXT/MD': {'txt', 'log', 'md', 'markdown'},
    'HTML': {'html', 'htm'},
  };

  String get _root => widget.rootPath;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    _list();
  }

  void _list() {
    try {
      final dir = Directory(_path);
      final all = dir.listSync();
      final dirs = <Directory>[];
      final files = <File>[];
      for (final e in all) {
        final name = e.path.split('/').last;
        if (name.startsWith('.')) continue;
        if (e is Directory) {
          dirs.add(e);
        } else if (e is File && Formats.isSupported(e.path)) {
          files.add(e);
        }
      }
      int cmp(FileSystemEntity a, FileSystemEntity b) => a.path
          .split('/')
          .last
          .toLowerCase()
          .compareTo(b.path.split('/').last.toLowerCase());
      dirs.sort(cmp);
      files.sort(cmp);
      setState(() {
        _entries = [...dirs, ...files];
        _error = null;
      });
    } catch (e) {
      setState(() {
        _entries = [];
        _error = S.cantAccess;
      });
    }
  }

  /// 확장자 모아보기: 현재 폴더부터 하위까지 재귀 수집 (최신 수정순)
  Future<void> _applyFilter(String? key) async {
    final gen = ++_collectGen;
    if (key == null) {
      setState(() {
        _filter = null;
        _collecting = false;
      });
      _list();
      return;
    }
    setState(() {
      _filter = key;
      _collecting = true;
      _entries = [];
      _error = null;
    });
    final exts = _groups[key]!;
    final found = <File>[];
    await _walk(Directory(_path), exts, found, 0);
    if (!mounted || gen != _collectGen) return;
    found.sort((a, b) {
      try {
        return b.statSync().modified.compareTo(a.statSync().modified);
      } catch (_) {
        return 0;
      }
    });
    setState(() {
      _entries = found;
      _collecting = false;
    });
  }

  Future<void> _walk(
      Directory d, Set<String> exts, List<File> out, int depth) async {
    if (depth > 6 || out.length >= 500) return;
    try {
      await for (final e in d.list(followLinks: false)) {
        if (out.length >= 500) return;
        final name = e.path.split('/').last;
        if (name.startsWith('.')) continue;
        if (e is Directory) {
          // 앱 전용 데이터 폴더는 방대하고 접근도 막혀 있다
          if (name == 'Android' && d.path == _root) continue;
          await _walk(e, exts, out, depth + 1);
        } else if (e is File && exts.contains(Formats.ext(e.path))) {
          out.add(e);
        }
      }
    } catch (_) {}
  }

  void _enter(String path) {
    setState(() => _path = path);
    _list();
  }

  bool get _atRoot => _path == _root || !_path.startsWith(_root);

  String _sizeText(File f) {
    try {
      final b = f.lengthSync();
      if (b < 1024) return '$b B';
      if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
      return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rel = _path == _root
        ? (widget.rootLabel ?? S.internalStorage)
        : _path.replaceFirst('$_root/', '');
    return PopScope(
      canPop: _atRoot && _filter == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_filter != null) {
          _applyFilter(null); // 뒤로가기 1회 = 필터 해제
        } else {
          _enter(_path.substring(0, _path.lastIndexOf('/')));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(rel, style: const TextStyle(fontSize: 16)),
          toolbarHeight: 48,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(S.all),
                      selected: _filter == null,
                      showCheckmark: false,
                      onSelected: (_) => _applyFilter(null),
                    ),
                  ),
                  for (final key in _groups.keys)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(key),
                        selected: _filter == key,
                        showCheckmark: false,
                        onSelected: (_) =>
                            _applyFilter(_filter == key ? null : key),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: _collecting
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(S.searchingFiles,
                          style: TextStyle(color: cs.outline, fontSize: 13)),
                    ],
                  ),
                )
              : _error != null
                  ? Center(child: Text(_error!, style: TextStyle(color: cs.outline)))
                  : _entries.isEmpty
                      ? Center(
                          child: Text(S.emptyFolder,
                              style: TextStyle(color: cs.outline)))
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, i) {
                            final e = _entries[i];
                            final name = e.path.split('/').last;
                            if (e is Directory) {
                              return ListTile(
                                leading: Icon(Icons.folder_outlined,
                                    color: cs.primary),
                                title: Text(name,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                dense: true,
                                onTap: () => _enter(e.path),
                              );
                            }
                            // 필터 모아보기에서는 파일이 어느 폴더에 있는지 보여준다
                            final parent = e.path
                                .substring(0, e.path.lastIndexOf('/'))
                                .replaceFirst(_root, '')
                                .replaceFirst(RegExp('^/'), '');
                            final sub = _filter != null && parent.isNotEmpty
                                ? '$parent · ${_sizeText(e as File)}'
                                : _sizeText(e as File);
                            return ListTile(
                              leading: DocThumb(path: e.path),
                              title: Text(name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle:
                                  Text(sub, style: const TextStyle(fontSize: 12)),
                              dense: true,
                              onTap: () => openFile(context, e.path),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
