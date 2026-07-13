import 'package:flutter/material.dart';

// Global notifier for in-app theme override.
// ThemeMode.system = follow device, dark/light = force override.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
