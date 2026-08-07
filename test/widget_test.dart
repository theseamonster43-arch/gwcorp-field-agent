// Smoke tests for the shared icon set. These deliberately avoid pumping the
// whole app, which would need Firebase initialised.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gwcorp_field_agent/widgets/gw_icons.dart';

void main() {
  testWidgets('GwIcon renders at the requested size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: GwIcon(GwIcons.home, size: 32, color: Colors.green)),
      ),
    );
    expect(find.byType(GwIcon), findsOneWidget);
    expect(tester.getSize(find.byType(GwIcon)), const Size(32, 32));
  });

  testWidgets('every icon in the set paints without throwing', (tester) async {
    const all = <String>[
      GwIcons.home, GwIcons.scan, GwIcons.chart, GwIcons.chat, GwIcons.box,
      GwIcons.recycle, GwIcons.alert, GwIcons.check, GwIcons.checkCircle,
      GwIcons.camera, GwIcons.clip, GwIcons.globe, GwIcons.pin, GwIcons.user,
      GwIcons.plus, GwIcons.menu, GwIcons.sparkle, GwIcons.satellite,
      GwIcons.chevronRight, GwIcons.chevronLeft, GwIcons.arrowRight,
      GwIcons.arrowUp, GwIcons.search, GwIcons.moon, GwIcons.trash,
      GwIcons.logout, GwIcons.mail, GwIcons.lock, GwIcons.eye, GwIcons.eyeOff,
      GwIcons.shield, GwIcons.image, GwIcons.close,
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [for (final d in all) GwIcon(d, size: 24)],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(GwIcon), findsNWidgets(all.length));
  });

  test('icon path data starts with a move command', () {
    // A path that does not open with M/m would draw from wherever the previous
    // subpath ended, which is how a glyph ends up with a stray connecting line.
    const all = {
      'home': GwIcons.home, 'scan': GwIcons.scan, 'chart': GwIcons.chart,
      'chat': GwIcons.chat, 'box': GwIcons.box, 'recycle': GwIcons.recycle,
      'alert': GwIcons.alert, 'check': GwIcons.check,
      'checkCircle': GwIcons.checkCircle, 'camera': GwIcons.camera,
      'clip': GwIcons.clip, 'globe': GwIcons.globe, 'pin': GwIcons.pin,
      'user': GwIcons.user, 'plus': GwIcons.plus, 'menu': GwIcons.menu,
      'sparkle': GwIcons.sparkle, 'satellite': GwIcons.satellite,
      'chevronRight': GwIcons.chevronRight, 'chevronLeft': GwIcons.chevronLeft,
      'arrowRight': GwIcons.arrowRight, 'arrowUp': GwIcons.arrowUp,
      'search': GwIcons.search, 'moon': GwIcons.moon, 'trash': GwIcons.trash,
      'logout': GwIcons.logout, 'mail': GwIcons.mail, 'lock': GwIcons.lock,
      'eye': GwIcons.eye, 'eyeOff': GwIcons.eyeOff, 'shield': GwIcons.shield,
      'image': GwIcons.image, 'close': GwIcons.close,
    };
    for (final entry in all.entries) {
      expect(entry.value.trimLeft().startsWith(RegExp('[Mm]')), isTrue,
          reason: '${entry.key} must start with a move command');
    }
  });
}
