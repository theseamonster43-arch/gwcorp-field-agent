import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

// Global notifier for in-app theme override.
// ThemeMode.system = follow device, dark/light = force override.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

/// Performance mode: drops the blur behind every glass surface.
///
/// GwGlass is a BackdropFilter, which makes the engine read back and blur
/// whatever is already painted underneath. One is cheap; a scrolling list of
/// them is comfortably the most expensive thing this app does on older
/// hardware. With this on, glass falls back to a plain translucent fill that
/// looks close and costs nothing.
final performanceModeNotifier = ValueNotifier<bool>(false);

/// Check for a newer desktop build on launch.
///
/// On by default: an agent running a months-old build is the likeliest way for
/// a fixed bug to keep being reported. Turning it off stops the check entirely
/// rather than just hiding the banner.
final autoUpdateNotifier = ValueNotifier<bool>(true);

// ── Persistence ─────────────────────────────────────────────────────────────
// Both notifiers above are in-memory only, so without this every preference
// resets on relaunch. A small JSON file rather than shared_preferences because
// path_provider is already a dependency and this is two scalars.

Future<File> _prefsFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}${Platform.pathSeparator}gw_prefs.json');
}

Future<void> _savePreferences() async {
  try {
    final file = await _prefsFile();
    await file.writeAsString(jsonEncode({
      'themeMode': themeModeNotifier.value.name,
      'performanceMode': performanceModeNotifier.value,
      'autoUpdate': autoUpdateNotifier.value,
    }));
  } catch (_) {
    // A preference that fails to save is not worth interrupting anyone over.
  }
}

/// Restores saved preferences, then keeps the file in step with every change.
///
/// Call once before runApp — reading after the first frame would make the app
/// visibly flip themes on launch.
Future<void> gwLoadPreferences() async {
  try {
    final file = await _prefsFile();
    if (await file.exists()) {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      themeModeNotifier.value = switch (map['themeMode']) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
      performanceModeNotifier.value = map['performanceMode'] == true;
      // Absent means never set, and the default is on.
      autoUpdateNotifier.value = map['autoUpdate'] != false;
    }
  } catch (_) {
    // Corrupt or unreadable file — fall back to defaults rather than crash.
  }

  themeModeNotifier.addListener(_savePreferences);
  performanceModeNotifier.addListener(_savePreferences);
  autoUpdateNotifier.addListener(_savePreferences);
}
