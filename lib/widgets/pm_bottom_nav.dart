import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bottom tab bar for the five `StatefulShellRoute` branches.
///
/// Two things make this resilient to a large system text scale (up to
/// 2.5x) without overflowing:
/// - The bar's own height grows moderately with the text scale (capped at
///   1.6x the base height) instead of staying rigid — a small, bounded
///   adaptation, not the sole fix.
/// - Each tab's icon+label is wrapped in a scale-down-only [FittedBox], so
///   if the (already-grown) available space still isn't enough at the most
///   extreme scales, the whole icon+label shrinks together to fit — the
///   label is never hidden or ellipsized, and at the default 1.0x-1.3x
///   scale this never has to shrink anything (it only ever scales *down*
///   from the natural size, never up).
/// Selection state is exposed to assistive technology via `Semantics
/// .selected` on each tab, not just visually by color.
class PmBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const PmBottomNav(
      {super.key, required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.home_rounded, label: 'Inicio'),
    (icon: Icons.calculate_rounded, label: 'Simulación'),
    (icon: Icons.calendar_month_rounded, label: 'Calendario'),
    (icon: Icons.fact_check_rounded, label: 'Estado'),
    (icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final barHeight = 64.0 * textScale.clamp(1.0, 1.6);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: barHeight,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == currentIndex;
              final color =
                  selected ? AppColors.greenEnd : AppColors.textSecondary;
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: selected ? '${item.label}, seleccionada' : item.label,
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(item.icon, color: color, size: 22),
                              const SizedBox(height: 4),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
