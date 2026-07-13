import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';

/// GitHub Releases 기반 인앱 업데이트.
/// 릴리스 태그는 v0.1.0 형식, 자산에 .apk 파일이 있어야 한다.
/// 저장소를 만든 뒤 아래 상수만 바꾸면 된다.
const String kGithubRepo = 'ChanchanCode/geunyang-reader';

/// 후원(밀크티) 링크. 실제 Buy Me a Coffee 핸들로 바꾸면 설정에 항목이 뜬다.
/// 'YOUR_HANDLE'이 남아 있으면 항목을 숨긴다.
const String kSponsorUrl = 'https://buymeacoffee.com/YOUR_HANDLE';
bool get kSponsorConfigured => !kSponsorUrl.contains('YOUR_HANDLE');

const _channel = MethodChannel('geunyang/native');

class Updater {
  static bool get configured => !kGithubRepo.startsWith('OWNER');

  /// 하루 한 번 자동 확인. 새 버전이 있으면 다이얼로그를 띄운다.
  /// APK 설치 방식이라 안드로이드 전용 (iOS는 TestFlight/App Store).
  static Future<void> autoCheck(BuildContext context) async {
    if (!Platform.isAndroid || !configured) return;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('last_update_check') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < 24 * 3600 * 1000) return;
    await prefs.setInt('last_update_check', now);
    if (!context.mounted) return;
    await check(context, silent: true);
  }

  static Future<void> check(BuildContext context, {bool silent = false}) async {
    if (!configured) {
      if (!silent && context.mounted) {
        _snack(context, S.updateNotConfigured);
      }
      return;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      final release = await _fetchLatest();
      final latest = (release['tag_name'] as String).replaceFirst('v', '');
      final apkUrl = _findApkUrl(release);
      if (apkUrl == null || !_isNewer(latest, info.version)) {
        if (!silent && context.mounted) {
          _snack(context, S.upToDate(info.version));
        }
        return;
      }
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(S.newVersion(latest)),
          content: Text(S.updateBody(info.version, latest)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(S.later)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(S.update)),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      await _downloadAndInstall(context, apkUrl, latest);
    } catch (e) {
      if (!silent && context.mounted) _snack(context, S.updateCheckFailed(e));
    }
  }

  static Future<Map<String, dynamic>> _fetchLatest() async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(
          Uri.parse('https://api.github.com/repos/$kGithubRepo/releases/latest'));
      req.headers.set('User-Agent', 'geunyang-reader');
      req.headers.set('Accept', 'application/vnd.github+json');
      final res = await req.close();
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      return jsonDecode(await res.transform(utf8.decoder).join())
          as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  static String? _findApkUrl(Map<String, dynamic> release) {
    final assets = (release['assets'] as List?) ?? [];
    for (final a in assets) {
      final name = a['name'] as String? ?? '';
      if (name.endsWith('.apk')) return a['browser_download_url'] as String?;
    }
    return null;
  }

  static bool _isNewer(String a, String b) {
    List<int> parse(String v) =>
        v.split('.').map((s) => int.tryParse(s.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
    final pa = parse(a), pb = parse(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static Future<void> _downloadAndInstall(
      BuildContext context, String url, String version) async {
    final progress = ValueNotifier<double?>(null);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(S.downloading),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (context, v, child) => LinearProgressIndicator(value: v),
        ),
      ),
    );
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/geunyang-reader-v$version.apk');
      final client = HttpClient();
      try {
        var uri = Uri.parse(url);
        HttpClientResponse res;
        // GitHub 릴리스 자산은 리다이렉트를 거친다
        while (true) {
          final req = await client.getUrl(uri);
          req.headers.set('User-Agent', 'geunyang-reader');
          req.followRedirects = false;
          res = await req.close();
          if (res.isRedirect) {
            uri = Uri.parse(res.headers.value(HttpHeaders.locationHeader)!);
            await res.drain();
            continue;
          }
          break;
        }
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        final total = res.contentLength;
        final sink = file.openWrite();
        var received = 0;
        await for (final chunk in res) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) progress.value = received / total;
        }
        await sink.close();
      } finally {
        client.close();
      }
      if (context.mounted) Navigator.pop(context);
      await _channel.invokeMethod('installApk', {'path': file.path});
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _snack(context, S.downloadFailed(e));
      }
    }
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
