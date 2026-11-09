import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';

class WalletAvatar extends StatelessWidget {
  const WalletAvatar({super.key, required this.wallet, this.size = 40});
  final Wallet wallet;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Color(wallet.color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(walletIcon(wallet.kind), size: size * 0.52, color: color),
    );
  }
}

/// White card with the spec's soft shadow.
class StashCard extends StatelessWidget {
  const StashCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = StashRadius.card,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        color: StashColors.card,
        borderRadius: r,
        boxShadow: StashShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Round gradient button (FAB, quick-input submit).
class GradientCircleButton extends StatelessWidget {
  const GradientCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.tooltip,
    this.elevated = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: StashGradients.cta,
        shape: BoxShape.circle,
        boxShadow: elevated
            ? const [BoxShadow(color: Color(0x4D007F88), offset: Offset(0, 8), blurRadius: 20)]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Small pill chip button used in the sub-navigation row.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StashColors.card,
      shape: const StadiumBorder(side: BorderSide(color: StashColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: StashColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: StashColors.text,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Small rounded tag, e.g. wallet type.
class TintBadge extends StatelessWidget {
  const TintBadge({super.key, required this.label, this.color = StashColors.primaryDark, this.tint = StashColors.primaryTint});

  final String label;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(StashRadius.pill)),
        child: Text(
          label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
        ),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      if (actionLabel != null)
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                actionLabel!,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: StashColors.primary),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: StashColors.primary),
            ]),
          ),
        ),
    ]);
  }
}

/// Pengeluaran / Pemasukan / Transfer switch; the selected tab takes the
/// colour of its transaction type.
class TxnTypeTabs extends StatelessWidget {
  const TxnTypeTabs({super.key, required this.selected, required this.onChanged});

  final TxnType selected;
  final ValueChanged<TxnType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: StashColors.subtle,
        borderRadius: BorderRadius.circular(StashRadius.pill),
      ),
      child: Row(children: [
        for (final t in TxnType.values)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: t == selected ? StashColors.forType(t) : Colors.transparent,
                  borderRadius: BorderRadius.circular(StashRadius.pill),
                ),
                alignment: Alignment.center,
                child: Text(
                  t.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: t == selected ? Colors.white : StashColors.muted,
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
