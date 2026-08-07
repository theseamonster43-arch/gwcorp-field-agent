import 'package:flutter/material.dart';
import '../theme/gw_theme.dart';

/// Presents [builder] as a rounded sheet over the current screen instead of a
/// full-screen push, so the tab bar and the page behind stay visible.
///
/// [builder] receives the sheet's own context — pop that one to dismiss.
Future<T?> showGwSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  double heightFactor = 0.92,
}) {
  final gw = GwTheme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: heightFactor,
      child: Column(
        children: [
          // Grab handle sits outside the clip so it reads as part of the sheet
          // chrome rather than the screen inside it.
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.45),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: gw.bg,
                  border: Border(
                    top: BorderSide(color: gw.border, width: 1),
                  ),
                ),
                // The sheet already clears the status bar via useSafeArea, so
                // strip the top inset the child would otherwise apply again.
                child: MediaQuery.removePadding(
                  context: sheetContext,
                  removeTop: true,
                  child: builder(sheetContext),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
