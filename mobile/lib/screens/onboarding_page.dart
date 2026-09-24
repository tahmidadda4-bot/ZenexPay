import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    ('ZenexPay', 'Complete Simple Tasks', 'Complete simple tasks from anywhere, anytime.', Icons.phone_android_rounded),
    ('Easy Tasks', 'Work with confidence', 'Pick clear tasks, follow the requirements and submit proof.', Icons.auto_awesome_rounded),
    ('Earn & Withdraw', 'Turn your time into earnings', 'Get approved rewards and manage your balance from one place.', Icons.account_balance_wallet_rounded),
  ];

  void _next() {
    if (_page == _slides.length - 1) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.surface, Color.alphaBlend(cs.primary.withOpacity(.10), cs.surface), Color.alphaBlend(cs.secondary.withOpacity(.08), cs.surface)])),
        child: SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.topRight, child: TextButton(
  onPressed: () {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  },
  child: const Text('Skip'),
)),
            Expanded(child: PageView.builder(controller: _controller, itemCount: _slides.length, onPageChanged: (v) => setState(() => _page = v), itemBuilder: (_, i) {
              final s = _slides[i];
              return Padding(padding: const EdgeInsets.fromLTRB(26, 8, 26, 18), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 210, height: 210, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFF146BFF), Color(0xFF7A35F4)]), boxShadow: [BoxShadow(color: cs.primary.withOpacity(.28), blurRadius: 42)]), child: Icon(s.$4, color: Colors.white, size: 88)),
                const SizedBox(height: 38), Text(s.$1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10), Text(s.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12), Text(s.$3, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, height: 1.45)),
              ]));
            })),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_slides.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 180), margin: const EdgeInsets.symmetric(horizontal: 4), width: _page == i ? 26 : 7, height: 7, decoration: BoxDecoration(color: _page == i ? cs.primary : cs.outlineVariant, borderRadius: BorderRadius.circular(99))))),
            const SizedBox(height: 20),
            Padding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 24), child: FilledButton(onPressed: _next, child: Text(_page == _slides.length - 1 ? 'Get Started' : 'Next'))),
          ]),
        ),
      ),
    );
  }
}
