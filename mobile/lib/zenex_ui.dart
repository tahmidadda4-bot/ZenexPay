import 'dart:ui';
import 'package:flutter/material.dart';

const Color kNavy = Color(0xFF060914);
const Color kNavy2 = Color(0xFF0B1020);
const Color kSurface = Color(0xFF10162A);
const Color kSurface2 = Color(0xFF151C33);
const Color kBlue = Color(0xFF4F8CFF);
const Color kPurple = Color(0xFF8B5CF6);
const Color kCyan = Color(0xFF36D7FF);
const Color kPink = Color(0xFFE946EF);

class ZenexPageBackground extends StatelessWidget {
  final Widget child;
  const ZenexPageBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF060914), Color(0xFF0A0F20), Color(0xFF070A15)]
              : const [Color(0xFFF8F9FF), Color(0xFFF1F4FF), Colors.white],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -90, right: -70, child: _GlowOrb(color: kPurple, size: 230)),
          Positioned(top: 220, left: -110, child: _GlowOrb(color: kCyan, size: 190)),
          Positioned(bottom: -110, right: -80, child: _GlowOrb(color: kPink, size: 220)),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(.10)),
          ),
        ),
      );
}

class ZenexGradient extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const ZenexGradient({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF238BFF), Color(0xFF8B5CF6), Color(0xFFE946EF)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: kPurple.withOpacity(.28), blurRadius: 30, offset: const Offset(0, 14))],
        ),
        child: child,
      );
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(.055) : Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: dark ? Colors.white.withOpacity(.10) : Colors.black.withOpacity(.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? .20 : .07), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Padding(padding: padding, child: child),
    );
    return onTap == null ? card : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(radius), child: card);
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -.2)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const IconTile(this.icon, {super.key, this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = color ?? kBlue;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.withOpacity(.20), c.withOpacity(.06)]),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: c.withOpacity(.16)),
      ),
      child: Icon(icon, color: c, size: size * .50),
    );
  }
}

class StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const StatPill({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.08),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withOpacity(.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [kPurple.withOpacity(.20), kCyan.withOpacity(.10)]), shape: BoxShape.circle),
                child: Icon(icon, size: 38, color: kCyan),
              ),
              const SizedBox(height: 18),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: Colors.grey, height: 1.45), textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Refresh')),
              ],
            ],
          ),
        ),
      );
}

String zenexMoney(dynamic value) {
  final n = double.tryParse('$value') ?? 0;
  return n.toStringAsFixed(2);
}
