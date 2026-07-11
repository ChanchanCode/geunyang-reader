import 'dart:io';

import 'package:flutter/material.dart';

import 'formats.dart';
import 'main.dart' show openFile;
import 'strings.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.initialPath});
  final String initialPath;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late String _path;
  List<FileSystemEntity> _entries = [];
  String? _error;

  static const _root = '/storage/emulated/0';

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
    final rel = _path == _root
        ? S.internalStorage
        : _path.replaceFirst('$_root/', '');
    return PopScope(
      canPop: _atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _enter(_path.substring(0, _path.lastIndexOf('/')));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(rel, style: const TextStyle(fontSize: 16)),
          toolbarHeight: 48,
        ),
        body: _error != null
            ? Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.outline)))
            : _entries.isEmpty
                ? Center(
                    child: Text(S.emptyFolder,
                        style: TextStyle(color: Theme.of(context).colorScheme.outline)))
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      final name = e.path.split('/').last;
                      if (e is Directory) {
                        return ListTile(
                          leading: Icon(Icons.folder_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          dense: true,
                          onTap: () => _enter(e.path),
                        );
                      }
                      return ListTile(
                        leading: Icon(Formats.icon(e.path)),
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_sizeText(e as File),
                            style: const TextStyle(fontSize: 12)),
                        dense: true,
                        onTap: () => openFile(context, e.path),
                      );
                    },
                  ),
      ),
    );
  }
}
