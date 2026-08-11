import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../theme/gw_theme.dart';
import 'gw_icons.dart';

/// Tells the agent their build is behind, with one tap to fix it.
///
/// Sits above the content rather than in a dialog: an update is worth knowing
/// about but never worth blocking work over, and a modal on launch is the
/// fastest way to train someone to dismiss things without reading them.
class GwUpdateBanner extends StatefulWidget {
  const GwUpdateBanner({super.key});

  @override
  State<GwUpdateBanner> createState() => _GwUpdateBannerState();
}

class _GwUpdateBannerState extends State<GwUpdateBanner> {
  /// Dismissed for this session only. The next launch checks again — a build
  /// that is out of date stays out of date.
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);

    return ValueListenableBuilder<GwRelease?>(
      valueListenable: UpdateService.available,
      builder: (context, release, _) {
        if (release == null || _hidden) return const SizedBox.shrink();

        return Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            decoration: BoxDecoration(
              color: gw.amber.withOpacity(.13),
              border: Border(
                bottom: BorderSide(color: gw.amber.withOpacity(.30)),
              ),
            ),
            child: Row(
              children: [
                GwIcon(GwIcons.sparkle, size: 16, color: gw.amber),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'This version of GWCORP is outdated — '
                        'update to get new features and bug patches.',
                        style: TextStyle(
                          color: gw.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You have ${UpdateService.runningVersion}, '
                        '${release.version} is available.',
                        style: TextStyle(color: gw.muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: UpdateService.openDownload,
                  style: TextButton.styleFrom(
                    backgroundColor: gw.green.withOpacity(.16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  child: Text(
                    'Update',
                    style: TextStyle(
                      color: gw.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _hidden = true),
                  iconSize: 13,
                  splashRadius: 16,
                  icon: GwIcon(GwIcons.close, size: 13, color: gw.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
