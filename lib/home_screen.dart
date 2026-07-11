import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'browser_screen.dart';
import 'formats.dart';
import 'main.dart' show openFile;
import 'prefs.dart';
import 'recents.dart';
import 'settings_screen.dart';
import 'strings.dart';
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
              children: [
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
              ],
            ),
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
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(S.fileGone)));
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
