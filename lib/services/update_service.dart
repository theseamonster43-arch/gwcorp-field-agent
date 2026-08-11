import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_preferences.dart';

/// What the published manifest says about the newest build.
class GwRelease {
  final String version;
  final int build;
  final String? notes;
  final String? windowsUrl;
  final String? macosUrl;

  const GwRelease({
    required this.version,
    required this.build,
    this.notes,
    this.windowsUrl,
    this.macosUrl,
  });

  /// The download for whichever desktop this is running on.
  String? get urlForThisPlatform {
    if (Platform.isWindows) return windowsUrl;
    if (Platform.isMacOS) return macosUrl;
    return null;
  }

  factory GwRelease.fromMap(Map<String, dynamic> m) => GwRelease(
        version: (m['version'] as String?) ?? '0.0.0',
        build: (m['build'] as num?)?.toInt() ?? 0,
        notes: m['notes'] as String?,
        windowsUrl: m['windows'] as String?,
        macosUrl: m['macos'] as String?,
      );
}

/// Checks whether this build is behind the published one.
///
/// Only desktop is checked: the phone builds are updated by their stores, and
/// prompting an agent to sideload an APK when Play already handles it would be
/// worse than saying nothing.
class UpdateService {
  static const _manifest = 'https://ihs-gwcorp.web.app/version.json';

  /// The newer release, once one is found. Screens watch this rather than
  /// polling — a banner can then appear the moment the check completes.
  static final available = ValueNotifier<GwRelease?>(null);

  /// Set when a manual check fails, so the UI can say so rather than looking
  /// like nothing happened.
  static String? lastError;

  static String _runningVersion = '';
  static int _runningBuild = 0;

  static String get runningVersion => _runningVersion;

  static bool get supported => Platform.isWindows || Platform.isMacOS;

  /// Reads the running version, then checks if [autoUpdateNotifier] allows it.
  ///
  /// Called at startup. A failure here is silent on purpose — an agent opening
  /// the app on a bad connection should not be greeted by an update error.
  static Future<void> checkOnLaunch() async {
    if (!supported) return;
    await _loadRunningVersion();
    if (!autoUpdateNotifier.value) return;
    await check(silent: true);
  }

  static Future<void> _loadRunningVersion() async {
    if (_runningBuild != 0) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _runningVersion = info.version;
      _runningBuild = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {
      // Leaves the build at 0, which makes any published build look newer.
      // Better to over-offer an update than to never offer one.
    }
  }

  /// Fetches the manifest and publishes [available] when it is ahead.
  ///
  /// Returns true when an update was found.
  static Future<bool> check({bool silent = false}) async {
    if (!supported) return false;
    await _loadRunningVersion();

    try {
      final res = await http
          .get(Uri.parse('$_manifest?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        lastError = 'Update check failed (${res.statusCode}).';
        return false;
      }

      final release = GwRelease.fromMap(
        Map<String, dynamic>.from(jsonDecode(res.body) as Map),
      );
      lastError = null;

      // Build number, not the version string: comparing "1.10.0" to "1.9.0"
      // as text gets it backwards, and the build always increments.
      if (release.build > _runningBuild) {
        available.value = release;
        return true;
      }
      available.value = null;
      return false;
    } catch (e) {
      lastError = silent ? null : 'Could not reach the update server.';
      // ignore: avoid_print
      print('UpdateService: $e');
      return false;
    }
  }

  /// Opens the download for this platform in the browser.
  ///
  /// Deliberately not a silent self-replacing update: swapping a running
  /// executable needs a helper process on Windows and a signed, notarised
  /// bundle on macOS. Handing over to the download is honest and works today.
  static Future<bool> openDownload() async {
    final url = available.value?.urlForThisPlatform ??
        'https://ihs-gwcorp.web.app/download.html';
    try {
      return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
