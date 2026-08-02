import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small "P PrestaMesta" wordmark used in the site header, reproduced
/// here as a simple badge + text lockup.
class PmLogo extends StatelessWidget {
  final double size;
  const PmLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.navy,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            'P',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'PrestaMesta',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: size * 0.6,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
