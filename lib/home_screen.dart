import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'browser_screen.dart';
import 'formats.dart';
import 'main.dart' show openFile;
import 'prefs.dart';
import 'recents.dart';
import 'settings_screen.dart';
import 'strings.dart';
import 'thumbs.dart';
import 'updater.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<RecentEntry> _recents = [];
  List<File> _recentDownloads = [];
  List<String> _favorites = [];
  List<_Shortcut> _shortcuts = [];
  bool _hasStorage = true;

  /// 메신저 등이 받은 파일을 두는 '공개' 폴더 후보. 앱 스코프(Android/data/*)는
  /// OS가 접근을 막지만, Android/media/* 와 DCIM·Download 하위는 권한으로 읽힌다.
  /// 라벨별로 첫 번째 '존재 + 지원 문서 있음' 폴더만 바로가기로 띄운다.
  static const _folderCandidates = <String, List<String>>{
    'KakaoTalk': [
      '/storage/emulated/0/DCIM/KakaoTalk',
      '/storage/emulated/0/KakaoTalkDownload',
      '/storage/emulated/0/Download/KakaoTalk',
    ],
    'Telegram': [
      '/storage/emulated/0/Android/media/org.telegram.messenger/Telegram',
      '/storage/emulated/0/Telegram',
      '/storage/emulated/0/Download/Telegram',
    ],
    'WhatsApp': [
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media',
      '/storage/emulated/0/WhatsApp/Media',
    ],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Prefs.revision.addListener(_onPrefs);
    _refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Updater.autoCheck(context);
    });
  }

  @override
  void dispose() {
    Prefs.revision.removeListener(_onPrefs);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onPrefs() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 설정에서 권한을 켜고 돌아온 경우 갱신
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    // iOS는 앱 샌드박스(Documents)만 다뤄서 저장소 권한이 필요 없다
    final granted =
        !Platform.isAndroid || await Permission.manageExternalStorage.isGranted;
    final recents = await Recents.load();
    final favorites = await Favorites.load();
    final downloads = granted ? await _loadRecentDownloads() : <File>[];
    final shortcuts = granted ? await _loadShortcuts() : <_Shortcut>[];
    if (!mounted) return;
    setState(() {
      _hasStorage = granted;
      _recents = recents;
      _favorites = favorites;
      _recentDownloads = downloads;
      _shortcuts = shortcuts;
    });
  }

  /// 외장 볼륨(SD 등) + 스마트 폴더(카톡 등) 바로가기 수집. 안드로이드 전용.
  Future<List<_Shortcut>> _loadShortcuts() async {
    if (!Platform.isAndroid) return [];
    final out = <_Shortcut>[];
    // 1) /storage 아래 외장 볼륨 — emulated·self 제외, 읽을 수 있는 것만
    try {
      for (final e in Directory('/storage').listSync()) {
        final name = e.path.split('/').last;
        if (name == 'emulated' || name == 'self' || e is! Directory) continue;
        try {
          e.listSync(); // 접근 가능?
          out.add(_Shortcut(S.sdcard, e.path, Icons.sd_card_outlined));
        } catch (_) {}
      }
    } catch (_) {}
    // 2) 메신저 등 공개 폴더 — 존재하고 지원 문서가 있는 것만
    for (final entry in _folderCandidates.entries) {
      for (final path in entry.value) {
        final dir = Directory(path);
        if (!dir.existsSync()) continue;
        if (await _hasSupported(dir, 0)) {
          out.add(_Shortcut(entry.key, path, Icons.folder_special_outlined));
          break; // 라벨당 하나
        }
      }
    }
    return out;
  }

  /// 폴더 하위에 지원 문서가 하나라도 있는지 (얕게, 예산 제한)
  Future<bool> _hasSupported(Directory d, int depth) async {
    if (depth > 3) return false;
    try {
      var seen = 0;
      await for (final e in d.list(followLinks: false)) {
        if (++seen > 300) return false;
        final name = e.path.split('/').last;
        if (name.startsWith('.')) continue;
        if (e is File && Formats.isSupported(e.path)) return true;
        if (e is Directory && await _hasSupported(e, depth + 1)) return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _togglePin(String path) async {
    final now = await Favorites.toggle(path);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(now ? S.pinAdded : S.pinRemoved),
      duration: const Duration(seconds: 1),
    ));
  }

  /// 다운로드 폴더(iOS는 앱 문서)에서 최근 수정된 지원 문서 5개
  Future<List<File>> _loadRecentDownloads() async {
    try {
      final dir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();
      final files = <File>[];
      await for (final e in Directory(dir.path).list(followLinks: false)) {
        if (e is File && Formats.isSupported(e.path)) files.add(e);
      }
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files.take(5).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _requestStorage() async {
    await Permission.manageExternalStorage.request();
    await _refresh();
  }

  void _browse(String path) {
    if (!_hasStorage) {
      _requestStorage();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BrowserScreen(initialPath: path)),
    ).then((_) => _refresh());
  }

  /// 지정한 루트로 탐색 (외장 볼륨·스마트 폴더 — 그 위로는 못 올라감)
  void _browseAt(String path, String label) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BrowserScreen(initialPath: path, rootPath: path, rootLabel: label),
      ),
    ).then((_) => _refresh());
  }

  /// iOS: 앱 Documents 폴더 탐색 (파일 앱 → '나의 iPhone > 그냥 리더'와 같은 공간)
  Future<void> _browseIosDocs() async {
    final dir = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrowserScreen(
          initialPath: dir.path,
          rootPath: dir.path,
          rootLabel: S.documents,
        ),
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: S.settings,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => _refresh()),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (!_hasStorage)
              Card(
                elevation: 0,
                color: cs.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.needStorageTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(S.needStorageBody,
                          style: TextStyle(fontSize: 13, color: cs.onSecondaryContainer)),
                      const SizedBox(height: 10),
                      FilledButton.tonal(
                        onPressed: _requestStorage,
                        child: Text(S.grantPermission),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: Platform.isAndroid
                  ? [
                      _QuickButton(
                        icon: Icons.download_outlined,
                        label: S.download,
                        onTap: () => _browse('/storage/emulated/0/Download'),
                      ),
                      const SizedBox(width: 10),
                      _QuickButton(
                        icon: Icons.description_outlined,
                        label: S.documents,
                        onTap: () => _browse('/storage/emulated/0/Documents'),
                      ),
                      const SizedBox(width: 10),
                      _QuickButton(
                        icon: Icons.smartphone_outlined,
                        label: S.allStorage,
                        onTap: () => _browse('/storage/emulated/0'),
                      ),
                    ]
                  : [
                      _QuickButton(
                        icon: Icons.description_outlined,
                        label: S.documents,
                        onTap: _browseIosDocs,
                      ),
                    ],
            ),
            if (_shortcuts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(S.shortcuts,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: cs.outline)),
              const SizedBox(height: 4),
              for (final s in _shortcuts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(s.icon, color: cs.primary),
                  title: Text(s.label,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    s.path.replaceFirst('/storage/emulated/0/', ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  dense: true,
                  onTap: () => _browseAt(s.path, s.label),
                ),
            ],
            if (_favorites.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(S.pinned,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: cs.outline)),
              const SizedBox(height: 4),
              for (final path in _favorites)
                Dismissible(
                  key: ValueKey('fav:$path'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    Favorites.remove(path);
                    setState(() => _favorites.remove(path));
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.push_pin_outlined, color: cs.outline),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: DocThumb(path: path),
                    title: Text(path.split('/').last,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      path.replaceFirst('/storage/emulated/0/', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      if (!File(path).existsSync()) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(S.fileGone)));
                        _refresh();
                        return;
                      }
                      await openFile(context, path);
                      _refresh();
                    },
                  ),
                ),
            ],
            if (_recentDownloads.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(S.recentDownloads,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: cs.outline)),
              const SizedBox(height: 4),
              for (final f in _recentDownloads)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: DocThumb(path: f.path),
                  title: Text(f.path.split('/').last,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    _mtimeText(f),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    await openFile(context, f.path);
                    _refresh();
                  },
                ),
            ],
            const SizedBox(height: 24),
            Text(S.recentFiles,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: cs.outline)),
            const SizedBox(height: 4),
            if (_recents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(S.noRecent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: cs.outline, height: 1.6)),
                ),
              )
            else
              for (final e in _recents)
                Dismissible(
                  key: ValueKey(e.path),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    Recents.remove(e.path);
                    setState(() => _recents.removeWhere((r) => r.path == e.path));
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete_outline, color: cs.error),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: DocThumb(path: e.path),
                    title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      e.path.replaceFirst('/storage/emulated/0/', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      if (!File(e.path).existsSync()) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(S.fileGone)));
                        _refresh();
                        return;
                      }
                      await openFile(context, e.path);
                      _refresh();
                    },
                    onLongPress: () => _togglePin(e.path),
                  ),
                ),
          ],
        ),
        ),
      ),
    );
  }

  String _mtimeText(File f) {
    try {
      final m = f.statSync().modified;
      final now = DateTime.now();
      final diff = now.difference(m);
      if (diff.inMinutes < 60) return S.ko ? '${diff.inMinutes}분 전' : '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return S.ko ? '${diff.inHours}시간 전' : '${diff.inHours}h ago';
      if (diff.inDays < 7) return S.ko ? '${diff.inDays}일 전' : '${diff.inDays}d ago';
      return '${m.year}.${m.month.toString().padLeft(2, '0')}.${m.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _Shortcut {
  const _Shortcut(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
