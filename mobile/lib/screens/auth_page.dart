import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reset_password_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final referralCode = TextEditingController();
  bool register = false, busy = false, obscure = true;

  Future<void> submit() async {
    final emailText = email.text.trim();
    final passwordText = password.text;
    final nameText = name.text.trim();
    final referralText = referralCode.text.trim().toUpperCase();
    if (!emailText.contains('@') || passwordText.length < 6 || (register && nameText.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete the fields. Password must be at least 6 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      if (register) {
        final response = await Supabase.instance.client.auth.signUp(
          email: emailText, password: passwordText,
          data: {'full_name': nameText, 'referral_code': referralText},
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.session == null ? 'Account created. Check your email if verification is enabled.' : 'Account created successfully.')));
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email: emailText, password: passwordText);
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override void dispose() { email.dispose(); password.dispose(); name.dispose(); referralCode.dispose(); super.dispose(); }
  InputDecoration deco(String label, IconData icon, {Widget? suffix}) => InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), suffixIcon: suffix);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050814),
      body: Stack(children: [
        Positioned(top: -120, right: -90, child: _GlowOrb(300, const Color(0xFF6D4AFF).withOpacity(.22))),
        Positioned(bottom: -160, left: -120, child: _GlowOrb(340, const Color(0xFF1488FF).withOpacity(.18))),
        SafeArea(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 470), child: Column(children: [
            Container(width: 78, height: 78, decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF3D8BFF), Color(0xFF7546FF)]), boxShadow: [BoxShadow(color: Color(0x525F65FF), blurRadius: 34, spreadRadius: 3)]), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 38)),
            const SizedBox(height: 18),
            const Text('ZenexPay', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('WORK  •  EARN  •  GROW', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.1)),
            const SizedBox(height: 30),
            Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: const Color(0xFF0D1325), borderRadius: BorderRadius.circular(17)), child: Row(children: [
              Expanded(child: _ModeButton('Sign In', !register, busy ? null : () => setState(() => register = false))),
              Expanded(child: _ModeButton('Create Account', register, busy ? null : () => setState(() => register = true))),
            ])),
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.fromLTRB(20, 22, 20, 20), decoration: BoxDecoration(color: const Color(0xFF0C1222), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white12), boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 30, offset: const Offset(0, 16))]), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(register ? 'Create your account' : 'Welcome back', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(register ? 'Create your ZenexPay account and start earning.' : 'Sign in to manage your tasks and earnings.', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45)),
              const SizedBox(height: 21),
              if (register) ...[TextField(controller: name, enabled: !busy, textCapitalization: TextCapitalization.words, style: const TextStyle(color: Colors.white), decoration: deco('Full name', Icons.person_outline_rounded)), const SizedBox(height: 12)],
              TextField(controller: email, enabled: !busy, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: deco('Email address', Icons.mail_outline_rounded)),
              const SizedBox(height: 12),
              TextField(controller: password, enabled: !busy, obscureText: obscure, style: const TextStyle(color: Colors.white), decoration: deco('Password', Icons.lock_outline_rounded, suffix: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
              if (!register) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())), child: const Text('Forgot password?'))),
              if (register) ...[TextField(controller: referralCode, enabled: !busy, textCapitalization: TextCapitalization.characters, style: const TextStyle(color: Colors.white), decoration: deco('Referral code (optional)', Icons.card_giftcard_outlined)), const SizedBox(height: 14)],
              SizedBox(height: 54, child: DecoratedBox(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3C8CFF), Color(0xFF7847FF)]), borderRadius: BorderRadius.circular(17)), child: FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent), child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(register ? 'Create Account' : 'Sign In', style: const TextStyle(fontWeight: FontWeight.w900))))),
              const SizedBox(height: 10),
              TextButton(onPressed: busy ? null : () => setState(() { register = !register; if (!register) referralCode.clear(); }), child: Text(register ? 'Already have an account? Sign in' : 'New to ZenexPay? Create an account')),
            ])),
            const SizedBox(height: 20),
            const Text('Secure account • Server-controlled wallet', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ])),
        ))),
      ]),
    );
  }
}
class _ModeButton extends StatelessWidget { final String text; final bool selected; final VoidCallback? onTap; const _ModeButton(this.text, this.selected, this.onTap); @override Widget build(BuildContext context) => AnimatedContainer(duration: const Duration(milliseconds: 180), height: 45, decoration: BoxDecoration(color: selected ? const Color(0xFF1A2440) : Colors.transparent, borderRadius: BorderRadius.circular(13)), child: TextButton(onPressed: onTap, child: Text(text, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontWeight: FontWeight.w800, fontSize: 12)))); }
class _GlowOrb extends StatelessWidget { final double size; final Color color; const _GlowOrb(this.size, this.color); @override Widget build(BuildContext context) => IgnorePointer(child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 30)]))); }
