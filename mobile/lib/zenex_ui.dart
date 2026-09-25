import 'package:flutter/material.dart';

const Color kNavy = Color(0xFF070B18);
const Color kNavy2 = Color(0xFF0D1225);
const Color kSurface = Color(0xFF11182B);
const Color kBlue = Color(0xFF4F8CFF);
const Color kPurple = Color(0xFF8B5CF6);
const Color kCyan = Color(0xFF36D7FF);

Color zenexBackground(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;
Color zenexPanel(BuildContext context) => Theme.of(context).colorScheme.surface;
Color zenexPrimaryText(BuildContext context) => Theme.of(context).colorScheme.onSurface;
Color zenexMutedText(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;
Color zenexSubtleBorder(BuildContext context) => Theme.of(context).dividerColor.withOpacity(.45);

class ZenexGradient extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const ZenexGradient({super.key, required this.child, this.padding});
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4D7CFE), Color(0xFF7C3AED), Color(0xFF5B35D5)],
      ),
    ),
    child: child,
  );
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF11182B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.55)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 22, offset: const Offset(0, 8))],
      ),
      child: Padding(padding: padding, child: child),
    );
    return onTap == null ? card : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: card);
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
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color))],
      ])),
      if (trailing != null) trailing!,
    ],
  );
}

class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const IconTile(this.icon, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(color: (color ?? kBlue).withOpacity(.13), borderRadius: BorderRadius.circular(14)),
    child: Icon(icon, color: color ?? kBlue, size: 22),
  );
}

class StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const StatPill({super.key, required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withOpacity(.10))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Colors.white70, size: 18), const SizedBox(height: 8),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ]),
  ));
}

class EmptyState extends StatelessWidget {
  final IconData icon; final String title; final String message; final VoidCallback? onRetry;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 76, height: 76, decoration: BoxDecoration(color: kBlue.withOpacity(.10), shape: BoxShape.circle), child: const Icon(Icons.inbox_rounded, size: 38, color: kBlue)),
    const SizedBox(height: 18), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
    const SizedBox(height: 8), Text(message, style: const TextStyle(color: Colors.grey, height: 1.45), textAlign: TextAlign.center),
    if (onRetry != null) ...[const SizedBox(height: 18), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Refresh'))],
  ])));
}

String zenexMoney(dynamic value) {
  final n = double.tryParse('$value') ?? 0;
  return n.toStringAsFixed(2);
}
