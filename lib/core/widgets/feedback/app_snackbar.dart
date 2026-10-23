import 'package:flutter/material.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';

/// Notifications visuelles flottantes (Snackbars / Toasts) non-intrusives
class AppSnackbar {
  static void showSuccess(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    _show(
      context,
      message: message,
      title: title,
      backgroundColor: AppColors.trafficFluid,
      icon: Icons.check_circle_outline_rounded,
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    _show(
      context,
      message: message,
      title: title,
      backgroundColor: AppColors.secondary,
      icon: Icons.error_outline_rounded,
    );
  }

  static void showWarning(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    _show(
      context,
      message: message,
      title: title,
      backgroundColor: const Color(0xFFE65100),
      icon: Icons.warning_amber_rounded,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    _show(
      context,
      message: message,
      title: title,
      backgroundColor: AppColors.primary,
      icon: Icons.info_outline_rounded,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    String? title,
    required Color backgroundColor,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 6,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
