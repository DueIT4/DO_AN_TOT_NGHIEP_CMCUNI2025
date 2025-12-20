import 'package:flutter/material.dart';

enum ToastType { success, error, info, warning }

class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context);

    final theme = Theme.of(context);

    Color bg;
    IconData icon;
    switch (type) {
      case ToastType.success:
        bg = Colors.green.shade600;
        icon = Icons.check_circle;
        break;
      case ToastType.error:
        bg = Colors.red.shade600;
        icon = Icons.error;
        break;
      case ToastType.warning:
        bg = Colors.orange.shade700;
        icon = Icons.warning_amber_rounded;
        break;
      case ToastType.info:
      default:
        bg = Colors.blue.shade600;
        icon = Icons.info;
        break;
    }

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final top = media.size.height * 0.18;

        return Positioned(
          top: top,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 18,
                        offset: Offset(0, 10),
                        color: Color(0x33000000),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    Future.delayed(duration, () => entry.remove());
  }
}
