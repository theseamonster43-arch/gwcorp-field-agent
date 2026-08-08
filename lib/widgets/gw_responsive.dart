import 'package:flutter/material.dart';

/// Layout breakpoint shared by every tab screen.
///
/// The same screens render on phones (inside [IosMainScreen], under a floating
/// tab bar) and on desktop (inside [DesktopShell], beside the icon rail), so
/// each one asks these helpers rather than hard-coding phone metrics.
const double gwWideBreakpoint = 760;

bool gwIsWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= gwWideBreakpoint;

/// Bottom padding for a scrolling page. Phones must clear the floating tab
/// bar; desktop has no bar, so reserving 120px there just leaves dead space.
double gwPageBottom(BuildContext context) => gwIsWide(context) ? 34 : 120;

/// Horizontal gutter — roomier on desktop.
double gwGutter(BuildContext context) => gwIsWide(context) ? 26 : 16;

/// Stat tiles run 4-up when there is room, 2-up on a phone.
int gwStatColumns(BuildContext context) => gwIsWide(context) ? 4 : 2;

/// Page title size.
double gwTitleSize(BuildContext context) => gwIsWide(context) ? 30 : 26;

/// Lays children out in one column on a phone and side by side when wide,
/// with [leftFlex]/[rightFlex] controlling the split.
class GwTwoUp extends StatelessWidget {
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double gap;

  const GwTwoUp({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.gap = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (!gwIsWide(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, SizedBox(height: gap), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: left),
        SizedBox(width: gap),
        Expanded(flex: rightFlex, child: right),
      ],
    );
  }
}
