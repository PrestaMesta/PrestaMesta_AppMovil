import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small "P PrestaMesta" wordmark used in the site header, reproduced
/// here as a simple badge + text lockup.
///
/// Wrapped in [FittedBox] (scale-down only) so it never overflows whatever
/// bounded width its host gives it (an `AppBar` title area shrunk by
/// actions, a `Form` header, ...) at a large system text scale — the
/// wordmark shrinks as a whole instead of clipping/ellipsizing. At the
/// default 1.0x scale this is a no-op: the badge+text already fit their
/// usual space, so nothing visibly changes. The single "P" glyph inside the
/// fixed circular badge is exempted from text scaling (`TextScaler
/// .noScaling`) because it's a decorative brand mark bound to a fixed-size
/// container, not body/informational text a user would need to grow to
/// read — the "PrestaMesta" wordmark next to it still scales normally.
class PmLogo extends StatelessWidget {
  final double size;
  const PmLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PrestaMesta',
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: ExcludeSemantics(
          child: Row(
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
                  textScaler: TextScaler.noScaling,
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
          ),
        ),
      ),
    );
  }
}
