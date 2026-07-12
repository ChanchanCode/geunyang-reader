import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'prefs.dart';
import 'strings.dart';
import 'updater.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _sectionTitle(S.general),
          ListTile(
            title: Text(S.language),
            trailing: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'system', label: Text(S.systemDefault)),
                const ButtonSegment(value: 'ko', label: Text('한국어')),
                const ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {Prefs.lang},
              onSelectionChanged: (v) => setState(() => Prefs.lang = v.first),
              showSelectedIcon: false,
            ),
          ),
          ListTile(
            title: Text(S.theme),
            trailing: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'system', label: Text(S.systemDefault)),
                ButtonSegment(value: 'light', label: Text(S.light)),
                ButtonSegment(value: 'dark', label: Text(S.dark)),
              ],
              selected: {Prefs.themeMode},
              onSelectionChanged: (v) => setState(() => Prefs.themeMode = v.first),
              showSelectedIcon: false,
            ),
          ),
          _sectionTitle(S.reading),
          ListTile(
            title: Text(S.fontSize),
            subtitle: Slider(
              value: Prefs.fontSize,
              min: 12,
              max: 24,
              divisions: 12,
              label: Prefs.fontSize.round().toString(),
              onChanged: (v) => setState(() => Prefs.fontSize = v),
            ),
            trailing: Text('${Prefs.fontSize.round()}px'),
          ),
          ListTile(
            title: Text(S.lineHeight),
            subtitle: Slider(
              value: Prefs.lineHeight,
              min: 1.2,
              max: 2.2,
              divisions: 10,
              label: Prefs.lineHeight.toStringAsFixed(1),
              onChanged: (v) => setState(() => Prefs.lineHeight = v),
            ),
            trailing: Text(Prefs.lineHeight.toStringAsFixed(1)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(S.readingHint,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(S.pageMode),
            subtitle: Text(S.pageModeHint, style: const TextStyle(fontSize: 12)),
            trailing: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'scroll',
                    label: Text(S.scrollMode),
                    icon: const Icon(Icons.swap_vert, size: 16)),
                ButtonSegment(
                    value: 'page',
                    label: Text(S.swipeMode),
                    icon: const Icon(Icons.swap_horiz, size: 16)),
              ],
              selected: {Prefs.pageMode},
              onSelectionChanged: (v) => setState(() => Prefs.pageMode = v.first),
              showSelectedIcon: false,
            ),
          ),
          SwitchListTile(
            title: Text(S.keepScreenOn),
            subtitle: Text(S.keepScreenOnHint, style: const TextStyle(fontSize: 12)),
            value: Prefs.keepScreenOn,
            onChanged: (v) => setState(() => Prefs.keepScreenOn = v),
          ),
          _sectionTitle(S.about),
          if (Platform.isAndroid)
            ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: Text(S.checkUpdate),
              onTap: () => Updater.check(context),
            ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(S.sourceCode),
            subtitle: const Text('github.com/$kGithubRepo', style: TextStyle(fontSize: 12)),
            onTap: () => launchUrl(Uri.parse('https://github.com/$kGithubRepo'),
                mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(S.version),
            subtitle: Text('v$_version'),
          ),
        ],
      ),
    );
  }
}
