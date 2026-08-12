import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../theme/gw_theme.dart';
import 'gw_icons.dart';

/// Tells the agent their build is behind, and updates it in place.
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

    // The success message wins: having just updated, "you are outdated" would
    // be both wrong and alarming.
    return ValueListenableBuilder<String?>(
      valueListenable: UpdateService.justUpdatedTo,
      builder: (context, updated, _) {
        if (updated != null && !_hidden) {
          return _bar(
            gw,
            accent: gw.green,
            icon: GwIcons.check,
            title: 'Updated to $updated',
            detail: 'You are on the latest version.',
            trailing: null,
          );
        }
        return _outdated(gw);
      },
    );
  }

  Widget _outdated(GwColors gw) {
    return ValueListenableBuilder<GwRelease?>(
      valueListenable: UpdateService.available,
      builder: (context, release, _) {
        if (release == null || _hidden) return const SizedBox.shrink();

        return ValueListenableBuilder<String?>(
          valueListenable: UpdateService.progress,
          builder: (context, progress, _) => _bar(
            gw,
            accent: gw.amber,
            icon: GwIcons.sparkle,
            title: progress ??
                'This version of GWCORP is outdated — '
                    'update to get new features and bug patches.',
            detail: progress != null
                ? 'The app will close while it installs.'
                : 'You have ${UpdateService.runningVersion}, '
                    '${release.version} is available.',
            // No button mid-download: the only thing left to do is wait, and
            // a second press would start another download.
            trailing: progress != null
                ? SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: gw.green,
                    ),
                  )
                : TextButton(
                    onPressed: UpdateService.downloadAndInstall,
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
          ),
        );
      },
    );
  }

  Widget _bar(
    GwColors gw, {
    required Color accent,
    required String icon,
    required String title,
    required String detail,
    required Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: BoxDecoration(
          color: accent.withOpacity(.13),
          border: Border(bottom: BorderSide(color: accent.withOpacity(.30))),
        ),
        child: Row(
          children: [
            GwIcon(icon, size: 16, color: accent),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: gw.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(color: gw.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (trailing != null) trailing,
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
  }
}
