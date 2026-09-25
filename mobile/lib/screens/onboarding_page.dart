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
    ('Complete Simple Tasks', 'Earn money from simple work, whenever you are ready.', Icons.smartphone_rounded, '1 / 3'),
    ('Easy Tasks', 'Pick clear tasks, follow the requirements and submit proof.', Icons.auto_awesome_rounded, '2 / 3'),
    ('Earn & Withdraw', 'Track your rewards and withdraw your approved earnings.', Icons.account_balance_wallet_rounded, '3 / 3'),
  ];

  Future<void> finish() async {
    if (busy) return;
    setState(() => busy = true);
    if (!widget.isTour && widget.onFinished != null) {
      await widget.onFinished!();
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ZenexGlowBackground(safeArea: false, child: SafeArea(child: Column(children: [
      if (widget.isTour) Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 0), child: Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)), const Text('App Tour', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]))
      else Padding(padding: const EdgeInsets.fromLTRB(22, 14, 18, 0), child: Row(children: [const ZenexLogo(size: 38), const Spacer(), TextButton(onPressed: busy ? null : finish, child: const Text('Skip'))])),
      Expanded(child: PageView.builder(controller: controller, itemCount: slides.length, onPageChanged: (v) => setState(() => page = v), itemBuilder: (_, i) {
        final s = slides[i];
        return Padding(padding: const EdgeInsets.fromLTRB(24, 10, 24, 18), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 250, height: 250, decoration: BoxDecoration(borderRadius: BorderRadius.circular(70), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F62FF), Color(0xFF7C36FF), Color(0xFFBD38FF)]), border: Border.all(color: kCyan.withOpacity(.35), width: 1.2), boxShadow: [BoxShadow(color: kPurple.withOpacity(.35), blurRadius: 48, spreadRadius: 3)]), child: Stack(alignment: Alignment.center, children: [Positioned(top: 22, right: 28, child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(.75), size: 22)), Positioned(bottom: 28, left: 25, child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(.55), size: 17)), Container(width: 116, height: 116, decoration: BoxDecoration(color: Colors.white.withOpacity(.11), borderRadius: BorderRadius.circular(34), border: Border.all(color: Colors.white.withOpacity(.18))), child: Icon(s.$3, color: Colors.white, size: 62))])),
          const SizedBox(height: 34),
          const Text('ZenexPay', style: TextStyle(fontSize: 18, color: kCyan, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(s.$1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, height: 1.05)),
          const SizedBox(height: 12),
          Text(s.$2, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: zenexMutedText(context), height: 1.5)),
          const SizedBox(height: 20),
          Text(s.$4, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
        ]));
      })),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(slides.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 180), margin: const EdgeInsets.symmetric(horizontal: 4), width: page == i ? 30 : 7, height: 7, decoration: BoxDecoration(color: page == i ? kCyan : Colors.white24, borderRadius: BorderRadius.circular(99))))),
      Padding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 24), child: SizedBox(width: double.infinity, height: 54, child: FilledButton(onPressed: busy ? null : () { if (page == slides.length - 1) { finish(); } else { controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic); } }, child: Text(page == slides.length - 1 ? 'Get Started' : 'Next')))),
    ]))),
  );
}
