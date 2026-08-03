import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../theme/app_theme.dart';

/// A persistent, always-visible error surface — deliberately not a
/// `SnackBar`, which can be missed (it auto-dismisses) and isn't reliably
/// read by screen readers as "something important changed". Shows
/// [AppException.mensaje] as the primary message; when the server included a
/// `requestId`, it's shown small and secondary, as a support reference —
/// never as the main message.
class AuthErrorBanner extends StatelessWidget {
  final AppException error;

  const AuthErrorBanner({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final requestId = error.requestId;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFCE8E8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF2B8B8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 20, color: Color(0xFFB3261E)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error.mensaje,
                    style: const TextStyle(
                      color: Color(0xFFB3261E),
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  if (requestId != null && requestId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Referencia: $requestId',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
