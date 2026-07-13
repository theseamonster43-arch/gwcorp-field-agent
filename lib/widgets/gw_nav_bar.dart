import 'package:flutter/material.dart';
import '../theme/gw_theme.dart';

class GwNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const GwNavBar({super.key, required this.title, this.onBack, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Container(
      color: gw.bg2,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  color: gw.muted,
                  onPressed: onBack,
                )
              else
                const SizedBox(width: 16),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: gw.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3)),
              ),
              ...actions,
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
