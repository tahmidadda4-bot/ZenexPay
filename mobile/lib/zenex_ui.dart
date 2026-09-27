import 'dart:ui';
import 'package:flutter/material.dart';

const Color kNavy = Color(0xFF020617);
const Color kNavy2 = Color(0xFF07112B);
const Color kSurface = Color(0xFF091A3A);
const Color kSurface2 = Color(0xFF0D2450);
const Color kBlue = Color(0xFF149BFF);
const Color kPurple = Color(0xFF7C3DFF);
const Color kCyan = Color(0xFF19E6FF);
const Color kPink = Color(0xFFE43DFF);
const Color kGreen = Color(0xFF35E89A);

Color zenexBackground(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;
Color zenexPanel(BuildContext context) => Theme.of(context).colorScheme.surface;
Color zenexPrimaryText(BuildContext context) => Theme.of(context).colorScheme.onSurface;
Color zenexMutedText(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;
Color zenexSubtleBorder(BuildContext context) => Theme.of(context).dividerColor.withOpacity(.62);

class ZenexLogo extends StatelessWidget {
  final double size;
  final bool showText;
  const ZenexLogo({super.key, this.size = 54, this.showText = false});

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ZMarkPainter()),
    );
    if (!showText) return mark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      mark,
      SizedBox(width: size * .20),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        RichText(text: TextSpan(children: const [
          TextSpan(text: 'Zenex', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          TextSpan(text: 'Pay', style: TextStyle(color: kPink, fontSize: 24, fontWeight: FontWeight.w900)),
        ])),
        const Text('WORK  •  EARN  •  GROW', style: TextStyle(color: Colors.white60, fontSize: 8, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
      ]),
    ]);
  }
}

class _ZMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [kPink, kPurple, kBlue, kCyan]).createShader(rect);
    final glow = Paint()..shader = shader..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final main = Paint()..shader = shader;
    final p = Path()
      ..moveTo(size.width * .16, size.height * .18)
      ..lineTo(size.width * .84, size.height * .18)
      ..lineTo(size.width * .68, size.height * .39)
      ..lineTo(size.width * .48, size.height * .39)
      ..lineTo(size.width * .79, size.height * .66)
      ..lineTo(size.width * .62, size.height * .84)
      ..lineTo(size.width * .15, size.height * .84)
      ..lineTo(size.width * .31, size.height * .62)
      ..lineTo(size.width * .49, size.height * .62)
      ..lineTo(size.width * .20, size.height * .37)
      ..close();
    canvas.drawPath(p, glow);
    canvas.drawPath(p, main);
    final shine = Paint()..color = Colors.white.withOpacity(.30)..strokeWidth = size.width * .035..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(size.width * .23, size.height * .27), Offset(size.width * .67, size.height * .27), shine);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ZenexGlowBackground extends StatelessWidget {
  final Widget child;
  final bool safeArea;
  const ZenexGlowBackground({super.key, required this.child, this.safeArea = true});
  @override
  Widget build(BuildContext context) {
    final body = Stack(children: [
      Positioned(top: -150, left: -120, child: _orb(290, kBlue.withOpacity(.10))),
      Positioned(top: 120, right: -150, child: _orb(310, kPurple.withOpacity(.13))),
      Positioned(bottom: -170, left: -20, child: _orb(330, kPink.withOpacity(.08))),
      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GlowLinesPainter()))),
      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GridPainter()))),
      child,
    ]);
    return safeArea ? SafeArea(child: body) : body;
  }
  Widget _orb(double size, Color color) => ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42), child: Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)));
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(.012)..strokeWidth = 1;
    const gap = 46.0;
    for (double x = 0; x < size.width; x += gap) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += gap) canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlowLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.1..color = kBlue.withOpacity(.10);
    final path = Path()..moveTo(-20, size.height * .78)..cubicTo(size.width * .20, size.height * .48, size.width * .44, size.height * .95, size.width * .64, size.height * .60)..cubicTo(size.width * .82, size.height * .30, size.width * 1.02, size.height * .50, size.width + 20, size.height * .20);
    canvas.drawPath(path, p);
    final p2 = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = kPurple.withOpacity(.10);
    final path2 = Path()..moveTo(-10, size.height * .92)..cubicTo(size.width * .22, size.height * .65, size.width * .45, size.height * 1.02, size.width * .72, size.height * .62)..cubicTo(size.width * .88, size.height * .40, size.width, size.height * .48, size.width + 15, size.height * .33);
    canvas.drawPath(path2, p2);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ZenexGradient extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const ZenexGradient({super.key, required this.child, this.padding});
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kBlue, kPurple, kPink]),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: kPurple.withOpacity(.28), blurRadius: 24, offset: const Offset(0, 9))],
    ),
    child: child,
  );
}

class NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  const NeonButton({super.key, required this.label, this.onPressed, this.icon, this.height = 52});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: height,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kBlue, kPurple, kPink]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: kPurple.withOpacity(.26), blurRadius: 22, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    ),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xCC071633) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dark ? const Color(0xFF1454A8) : Theme.of(context).dividerColor.withOpacity(.55), width: 1),
        boxShadow: [
          BoxShadow(color: glow ? kPurple.withOpacity(.20) : Colors.black.withOpacity(.10), blurRadius: glow ? 28 : 18, offset: const Offset(0, 8)),
          if (glow) BoxShadow(color: kBlue.withOpacity(.08), blurRadius: 18),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    return onTap == null ? card : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: card);
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
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: TextStyle(fontSize: 10, color: zenexMutedText(context)))],
    ])),
    if (trailing != null) trailing!,
  ]);
}

class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const IconTile(this.icon, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Container(width: 44, height: 44, decoration: BoxDecoration(gradient: LinearGradient(colors: [(color ?? kBlue).withOpacity(.20), kPurple.withOpacity(.10)]), borderRadius: BorderRadius.circular(14), border: Border.all(color: (color ?? kBlue).withOpacity(.25))), child: Icon(icon, color: color ?? kBlue, size: 21));
}

class StatPill extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const StatPill({super.key, required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.09))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Colors.white70, size: 18), const SizedBox(height: 8), Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9))])));
}

class ZenexIllustration extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final Color accent;
  final double size;
  const ZenexIllustration({super.key, required this.icon, this.badge, this.accent = kBlue, this.size = 230});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .27),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF081A46), Color(0xFF11105A), Color(0xFF300A5A)]),
      border: Border.all(color: accent.withOpacity(.38)),
      boxShadow: [BoxShadow(color: accent.withOpacity(.16), blurRadius: 36), BoxShadow(color: kPink.withOpacity(.10), blurRadius: 58)],
    ),
    child: Stack(alignment: Alignment.center, children: [
      Positioned(top: 22, right: 26, child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(.75), size: 20)),
      Positioned(bottom: 28, left: 26, child: Icon(Icons.auto_awesome, color: kCyan.withOpacity(.55), size: 16)),
      Container(width: size * .46, height: size * .46, decoration: BoxDecoration(color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(size * .14), border: Border.all(color: Colors.white.withOpacity(.13))), child: Icon(icon, color: Colors.white, size: size * .24)),
      if (badge != null) Positioned(right: 20, bottom: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: kPink.withOpacity(.85), borderRadius: BorderRadius.circular(99)), child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)))),
    ]),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon; final String title; final String message; final VoidCallback? onRetry;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 76, height: 76, decoration: BoxDecoration(color: kBlue.withOpacity(.10), shape: BoxShape.circle, border: Border.all(color: kBlue.withOpacity(.25))), child: Icon(icon, size: 36, color: kBlue)), const SizedBox(height: 18), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900), textAlign: TextAlign.center), const SizedBox(height: 8), Text(message, style: TextStyle(color: zenexMutedText(context), height: 1.45), textAlign: TextAlign.center), if (onRetry != null) ...[const SizedBox(height: 18), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Refresh'))]])));
}

String zenexMoney(dynamic value) => (double.tryParse('$value') ?? 0).toStringAsFixed(2);
