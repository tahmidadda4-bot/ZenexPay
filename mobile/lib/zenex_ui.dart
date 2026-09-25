import 'dart:ui';
import 'package:flutter/material.dart';

const Color kNavy = Color(0xFF050814);
const Color kNavy2 = Color(0xFF0A1022);
const Color kSurface = Color(0xFF0E1730);
const Color kSurface2 = Color(0xFF111D3B);
const Color kBlue = Color(0xFF39A7FF);
const Color kPurple = Color(0xFF8B43FF);
const Color kCyan = Color(0xFF29E7FF);
const Color kPink = Color(0xFFD84BFF);

Color zenexBackground(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;
Color zenexPanel(BuildContext context) => Theme.of(context).colorScheme.surface;
Color zenexPrimaryText(BuildContext context) => Theme.of(context).colorScheme.onSurface;
Color zenexMutedText(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;
Color zenexSubtleBorder(BuildContext context) => Theme.of(context).dividerColor.withOpacity(.50);

class ZenexLogo extends StatelessWidget {
  final double size;
  final bool showText;
  const ZenexLogo({super.key, this.size = 54, this.showText = false});

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPink, kPurple, kBlue, kCyan],
        ),
        boxShadow: [BoxShadow(color: kPurple.withOpacity(.35), blurRadius: 22)],
      ),
      child: Center(
        child: Text('Z', style: TextStyle(color: Colors.white, fontSize: size * .58, fontWeight: FontWeight.w900, height: 1)),
      ),
    );
    if (!showText) return mark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      mark,
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        RichText(text: const TextSpan(children: [
          TextSpan(text: 'Zenex', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          TextSpan(text: 'Pay', style: TextStyle(color: kPink, fontSize: 24, fontWeight: FontWeight.w900)),
        ])),
        const Text('WORK  •  EARN  •  GROW', style: TextStyle(color: Colors.white60, fontSize: 8, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
      ]),
    ]);
  }
}

class ZenexGlowBackground extends StatelessWidget {
  final Widget child;
  final bool safeArea;
  const ZenexGlowBackground({super.key, required this.child, this.safeArea = true});
  @override
  Widget build(BuildContext context) {
    final body = Stack(children: [
      Positioned(top: -130, left: -100, child: _orb(250, kBlue.withOpacity(.11))),
      Positioned(top: 110, right: -130, child: _orb(260, kPurple.withOpacity(.12))),
      Positioned(bottom: -160, left: 40, child: _orb(280, kPink.withOpacity(.07))),
      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GridPainter()))),
      child,
    ]);
    return safeArea ? SafeArea(child: body) : body;
  }
  Widget _orb(double size, Color color) => ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), child: Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)));
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(.018)..strokeWidth = 1;
    const gap = 44.0;
    for (double x = 0; x < size.width; x += gap) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += gap) canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ZenexGradient extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const ZenexGradient({super.key, required this.child, this.padding});
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF126CFF), Color(0xFF733BFF), Color(0xFFB53BFF)])),
    child: child,
  );
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool glow;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.glow = false});
  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0D1730) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF244C96) : Theme.of(context).dividerColor.withOpacity(.55)),
        boxShadow: [BoxShadow(color: glow ? kPurple.withOpacity(.18) : Colors.black.withOpacity(.08), blurRadius: glow ? 26 : 20, offset: const Offset(0, 9))],
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
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: TextStyle(fontSize: 11, color: zenexMutedText(context)))],
    ])),
    if (trailing != null) trailing!,
  ]);
}

class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const IconTile(this.icon, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Container(width: 44, height: 44, decoration: BoxDecoration(color: (color ?? kBlue).withOpacity(.13), borderRadius: BorderRadius.circular(14), border: Border.all(color: (color ?? kBlue).withOpacity(.20))), child: Icon(icon, color: color ?? kBlue, size: 22));
}

class StatPill extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const StatPill({super.key, required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withOpacity(.10))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Colors.white70, size: 18), const SizedBox(height: 8), Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10))])));
}

class EmptyState extends StatelessWidget {
  final IconData icon; final String title; final String message; final VoidCallback? onRetry;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 76, height: 76, decoration: BoxDecoration(color: kBlue.withOpacity(.10), shape: BoxShape.circle, border: Border.all(color: kBlue.withOpacity(.25))), child: Icon(icon, size: 36, color: kBlue)), const SizedBox(height: 18), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900), textAlign: TextAlign.center), const SizedBox(height: 8), Text(message, style: TextStyle(color: zenexMutedText(context), height: 1.45), textAlign: TextAlign.center), if (onRetry != null) ...[const SizedBox(height: 18), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Refresh'))]])));
}

String zenexMoney(dynamic value) => (double.tryParse('$value') ?? 0).toStringAsFixed(2);
