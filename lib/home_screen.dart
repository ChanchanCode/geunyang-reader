import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'browser_screen.dart';
import 'formats.dart';
import 'main.dart' show openFile;
import 'recents.dart';
import 'updater.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<RecentEntry> _recents = [];
  bool _hasStorage = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Updater.autoCheck(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 설정에서 권한을 켜고 돌아온 경우 갱신
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final granted = await Permission.manageExternalStorage.isGranted;
    final recents = await Recents.load();
    if (!mounted) return;
    setState(() {
      _hasStorage = granted;
      _recents = recents;
    });
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

  Future<void> _showAbout() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    showAboutDialog(
      context: context,
      applicationName: '그냥 리더',
      applicationVersion: 'v${info.version}',
      applicationLegalese:
          '광고 없는 문서 뷰어.\npdf · docx · hwp · hwpx · html · md · txt · xlsx · epub',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('그냥 리더'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'update') Updater.check(context);
              if (v == 'about') _showAbout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'update', child: Text('업데이트 확인')),
              PopupMenuItem(value: 'about', child: Text('정보')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
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
                      const Text('저장소 접근 권한이 필요해요',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('기기의 문서 파일을 읽기 위한 권한이에요. 한 번만 허용하면 돼요.',
                          style: TextStyle(fontSize: 13, color: cs.onSecondaryContainer)),
                      const SizedBox(height: 10),
                      FilledButton.tonal(
                        onPressed: _requestStorage,
                        child: const Text('권한 허용하기'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                _QuickButton(
                  icon: Icons.download_outlined,
                  label: '다운로드',
                  onTap: () => _browse('/storage/emulated/0/Download'),
                ),
                const SizedBox(width: 10),
                _QuickButton(
                  icon: Icons.description_outlined,
                  label: '문서',
                  onTap: () => _browse('/storage/emulated/0/Documents'),
                ),
                const SizedBox(width: 10),
                _QuickButton(
                  icon: Icons.smartphone_outlined,
                  label: '전체',
                  onTap: () => _browse('/storage/emulated/0'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('최근 파일',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: cs.outline)),
            const SizedBox(height: 4),
            if (_recents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('아직 연 파일이 없어요.\n위에서 폴더를 열거나, 파일 앱에서 문서를 탭해 보세요.',
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
                    leading: Icon(Formats.icon(e.path)),
                    title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      e.path.replaceFirst('/storage/emulated/0/', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      if (!File(e.path).existsSync()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('파일이 삭제되었거나 이동했어요')));
                        _refresh();
                        return;
                      }
                      await openFile(context, e.path);
                      _refresh();
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
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
