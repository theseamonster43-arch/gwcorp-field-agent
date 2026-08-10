import 'package:flutter/material.dart';

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
