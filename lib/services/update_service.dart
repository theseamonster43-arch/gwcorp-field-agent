import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
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
    await _detectJustUpdated();
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

  /// Progress text while an update downloads. Null when idle.
  static final progress = ValueNotifier<String?>(null);

  /// Set on the first launch after an update, so the app can confirm it
  /// worked. An update that finishes silently is indistinguishable from one
  /// that failed — the agent quit the app, something flashed, and now they are
  /// looking at the same screen wondering.
  static final justUpdatedTo = ValueNotifier<String?>(null);

  /// Compares the running version against the one recorded last launch.
  static Future<void> _detectJustUpdated() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final marker = File('${dir.path}${Platform.pathSeparator}gw_version');

      final previous =
          await marker.exists() ? (await marker.readAsString()).trim() : '';
      if (previous.isNotEmpty && previous != _runningVersion) {
        justUpdatedTo.value = _runningVersion;
      }
      if (previous != _runningVersion) {
        await marker.writeAsString(_runningVersion);
      }
    } catch (_) {
      // Not worth surfacing: the confirmation is a nicety, not the update.
    }
  }

  /// Downloads the new build and hands off to the installer.
  ///
  /// Windows only. The app cannot overwrite itself — Windows memory-maps
  /// files like icudtl.dat for the life of the process — so the installer is
  /// launched and this process exits, leaving it free to replace everything.
  /// The installer closes any straggler before extracting.
  ///
  /// Falls back to opening the download page anywhere else.
  static Future<bool> downloadAndInstall() async {
    final release = available.value;
    if (!Platform.isWindows || release?.windowsUrl == null) {
      return openDownload();
    }

    try {
      progress.value = 'Downloading…';
      final res = await http
          .get(Uri.parse(release!.windowsUrl!))
          .timeout(const Duration(minutes: 5));
      if (res.statusCode != 200) {
        progress.value = null;
        return openDownload();
      }

      final dir = await getTemporaryDirectory();
      final zip = File('${dir.path}${Platform.pathSeparator}gw_update.zip');
      await zip.writeAsBytes(res.bodyBytes);

      progress.value = 'Preparing…';
      final outDir = '${dir.path}${Platform.pathSeparator}gw_update';
      // Expand-Archive rather than a Dart unzip: it is already there, and the
      // package only needs unpacking once before the installer takes over.
      final unzip = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Expand-Archive -Path "${zip.path}" -DestinationPath "$outDir" -Force',
      ]);
      if (unzip.exitCode != 0) {
        progress.value = null;
        return openDownload();
      }

      final installer = File('$outDir${Platform.pathSeparator}GWCORP_Installer.exe');
      if (!await installer.exists()) {
        progress.value = null;
        return openDownload();
      }

      progress.value = 'Starting installer…';
      // Detached: it has to outlive this process, which is about to end.
      await Process.start(
        installer.path,
        const [],
        mode: ProcessStartMode.detached,
        workingDirectory: outDir,
      );

      await Future<void>.delayed(const Duration(milliseconds: 600));
      exit(0);
    } catch (e) {
      progress.value = null;
      // ignore: avoid_print
      print('UpdateService.install: $e');
      return openDownload();
    }
  }

  /// Opens the download for this platform in the browser.
  ///
  /// The fallback when the in-app path cannot run — macOS needs the DMG
  /// mounted by hand, and any download failure is better ending at a working
  /// page than a dead end.
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
