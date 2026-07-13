import 'dart:io';

import 'package:flutter/material.dart';

import 'formats.dart';
import 'main.dart' show openFile;
import 'recents.dart';
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

enum _Sort { name, date, size }

class _BrowserScreenState extends State<BrowserScreen> {
  late String _path;
  List<FileSystemEntity> _entries = [];
  String? _error;
  String? _filter; // 확장자 그룹 키 (null = 폴더 보기)
  bool _collecting = false;
  int _collectGen = 0; // 필터 전환 시 이전 수집 결과 무시용
  _Sort _sort = _Sort.name;
  bool _sortDesc = false;
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _groups = <String, Set<String>>{
    'PDF': {'pdf'},
    'HWP': {'hwp', 'hwpx'},
    'Word': {'docx'},
    'PPT': {'pptx'},
    'Excel': {'xlsx', 'xls', 'csv'},
    'EPUB': {'epub'},
    'IMG': Formats.image,
    'TXT/MD': {'txt', 'log', 'md', 'markdown'},
    'CODE': Formats.code,
    'HTML': {'html', 'htm'},
  };

  String get _root => widget.rootPath;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    _list();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _cmp(FileSystemEntity a, FileSystemEntity b) {
    int r;
    switch (_sort) {
      case _Sort.name:
        r = a.path
            .split('/')
            .last
            .toLowerCase()
            .compareTo(b.path.split('/').last.toLowerCase());
      case _Sort.date:
        try {
          r = b.statSync().modified.compareTo(a.statSync().modified);
        } catch (_) {
          r = 0;
        }
      case _Sort.size:
        try {
          final sa = a is File ? a.lengthSync() : 0;
          final sb = b is File ? b.lengthSync() : 0;
          r = sb.compareTo(sa);
        } catch (_) {
          r = 0;
        }
    }
    return _sortDesc ? -r : r;
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
      dirs.sort(_cmp);
      files.sort(_cmp);
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

  void _resort() {
    if (_filter != null) {
      setState(() => _entries.sort(_cmp));
    } else {
      _list();
    }
  }

  /// 확장자 모아보기: 현재 폴더부터 하위까지 재귀 수집
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
    found.sort(_cmp);
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
    setState(() {
      _path = path;
      _filter = null;
      _collecting = false;
    });
    _list();
  }

  bool get _atRoot => _path == _root || !_path.startsWith(_root);

  /// 파일 삭제 (확인 후). 최근·고정 목록에서도 제거하고 현재 목록 갱신.
  Future<void> _confirmDelete(File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(f.path.split('/').last, style: const TextStyle(fontSize: 16)),
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
      await f.delete();
      await Recents.remove(f.path);
      await Favorites.remove(f.path);
      if (!mounted) return;
      setState(() => _entries.removeWhere((x) => x.path == f.path));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.deleteFailed)));
      }
    }
  }

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

  /// 루트 → 현재 폴더까지 경로 조각 (탭하면 그 폴더로 점프)
  List<MapEntry<String, String>> get _crumbs {
    final out = <MapEntry<String, String>>[
      MapEntry(widget.rootLabel ?? S.internalStorage, _root),
    ];
    if (_path != _root && _path.startsWith(_root)) {
      var acc = _root;
      for (final seg in _path.substring(_root.length + 1).split('/')) {
        acc = '$acc/$seg';
        out.add(MapEntry(seg, acc));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = _query.isEmpty
        ? _entries
        : _entries
            .where((e) => e.path
                .split('/')
                .last
                .toLowerCase()
                .contains(_query.toLowerCase()))
            .toList();
    return PopScope(
      canPop: _atRoot && _filter == null && !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_searching) {
          setState(() {
            _searching = false;
            _query = '';
            _searchCtrl.clear();
          });
        } else if (_filter != null) {
          _applyFilter(null); // 뒤로가기 1회 = 필터 해제
        } else {
          _enter(_path.substring(0, _path.lastIndexOf('/')));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 48,
          title: _searching
              ? TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: S.searchInFolder,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(
                      fontFamily: null, fontSize: 15, fontWeight: FontWeight.normal),
                  onChanged: (v) => setState(() => _query = v),
                )
              : Text(_path == _root
                  ? (widget.rootLabel ?? S.internalStorage)
                  : _path.split('/').last),
          actions: [
            IconButton(
              icon: Icon(_searching ? Icons.close : Icons.search),
              tooltip: S.searchInFolder,
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _query = '';
                  _searchCtrl.clear();
                }
              }),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              onSelected: (v) {
                setState(() {
                  final s = switch (v) {
                    'name' => _Sort.name,
                    'size' => _Sort.size,
                    _ => _Sort.date,
                  };
                  if (_sort == s) {
                    _sortDesc = !_sortDesc;
                  } else {
                    _sort = s;
                    _sortDesc = false;
                  }
                });
                _resort();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'name',
                    child: _sortLabel(S.sortName, _Sort.name)),
                PopupMenuItem(
                    value: 'date',
                    child: _sortLabel(S.sortDate, _Sort.date)),
                PopupMenuItem(
                    value: 'size',
                    child: _sortLabel(S.sortSize, _Sort.size)),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(82),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 경로 브레드크럼
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    reverse: true, // 항상 현재 폴더가 보이게
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _crumbs.length,
                    separatorBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(Icons.chevron_left,
                          size: 15, color: cs.outline),
                    ),
                    itemBuilder: (context, i) {
                      final c = _crumbs[_crumbs.length - 1 - i];
                      final isLast = i == 0;
                      return InkWell(
                        onTap: isLast ? null : () => _enter(c.value),
                        child: Center(
                          child: Text(
                            c.key,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isLast ? cs.onSurface : cs.outline,
                              fontWeight:
                                  isLast ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 확장자 필터 칩
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              ],
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
                  ? Center(
                      child: Text(_error!, style: TextStyle(color: cs.outline)))
                  : visible.isEmpty
                      ? Center(
                          child: Text(S.emptyFolder,
                              style: TextStyle(color: cs.outline)))
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, i) {
                            final e = visible[i];
                            final name = e.path.split('/').last;
                            if (e is Directory) {
                              return ListTile(
                                leading: Icon(Icons.folder_outlined,
                                    color: cs.primary),
                                title: Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
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
                              subtitle: Text(sub,
                                  style: const TextStyle(fontSize: 12)),
                              dense: true,
                              onTap: () => openFile(context, e.path),
                              onLongPress: () => _confirmDelete(e),
                            );
                          },
                        ),
        ),
      ),
    );
  }

  Widget _sortLabel(String text, _Sort s) {
    return Row(
      children: [
        Expanded(child: Text(text)),
        if (_sort == s)
          Icon(_sortDesc ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
      ],
    );
  }
}
