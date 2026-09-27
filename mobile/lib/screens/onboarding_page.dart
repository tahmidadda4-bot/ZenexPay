import 'package:flutter/material.dart';
import '../zenex_ui.dart';

class OnboardingPage extends StatefulWidget {
  final Future<void> Function()? onFinished;
  final bool isTour;
  const OnboardingPage({super.key, this.onFinished, this.isTour = false});
  @override State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final controller = PageController();
  int page = 0;
  bool busy = false;

  static const slides = [
    ('Complete Simple Tasks', 'Complete simple tasks and earn real money from your phone, whenever you are ready.', Icons.smartphone_rounded, '1 / 3'),
    ('Fast & Secure', 'Pick clear tasks, follow the requirements and submit your proof with confidence.', Icons.rocket_launch_rounded, '2 / 3'),
    ('Earn & Withdraw', 'Track your rewards, complete daily missions and withdraw approved earnings easily.', Icons.card_giftcard_rounded, '3 / 3'),
  ];

  Future<void> finish() async {
    if (busy) return;
    setState(() => busy = true);
    if (!widget.isTour && widget.onFinished != null) { await widget.onFinished!(); return; }
    if (mounted) Navigator.of(context).maybePop();
  }
  @override void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ZenexGlowBackground(safeArea: false, child: SafeArea(child: Column(children: [
      if (widget.isTour)
        Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 0), child: Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)), const Text('App Tour', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]))
      else
        Padding(padding: const EdgeInsets.fromLTRB(22, 14, 18, 0), child: Row(children: [const ZenexLogo(size: 40), const Spacer(), TextButton(onPressed: busy ? null : finish, child: const Text('Skip'))])),
      Expanded(child: PageView.builder(controller: controller, itemCount: slides.length, onPageChanged: (v) => setState(() => page = v), itemBuilder: (_, i) {
        final s = slides[i];
        return Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 10), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ZenexIllustration(icon: s.$3, badge: i == 2 ? '+ rewards' : null, accent: i == 1 ? kCyan : kBlue, size: 255),
          const SizedBox(height: 26),
          const Text('ZenexPay', style: TextStyle(fontSize: 17, color: kCyan, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(s.$1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, height: 1.05)),
          const SizedBox(height: 11),
          Text(s.$2, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: zenexMutedText(context), height: 1.5)),
          const SizedBox(height: 14),
          Text(s.$4, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
        ]));
      })),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(slides.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 180), margin: const EdgeInsets.symmetric(horizontal: 4), width: page == i ? 28 : 7, height: 7, decoration: BoxDecoration(gradient: page == i ? const LinearGradient(colors: [kBlue, kPink]) : null, color: page == i ? null : Colors.white24, borderRadius: BorderRadius.circular(99))))),
      Padding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 24), child: NeonButton(label: page == slides.length - 1 ? 'Get Started' : 'Next  →', onPressed: busy ? null : () { if (page == slides.length - 1) finish(); else controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic); })),
    ]))),
  );
}
