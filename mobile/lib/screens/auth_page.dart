import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reset_password_page.dart';
import '../services/network_error.dart';
import '../services/supabase_service.dart';
import '../zenex_ui.dart';

class AuthPage extends StatefulWidget { const AuthPage({super.key}); @override State<AuthPage> createState() => _AuthPageState(); }
class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(), password = TextEditingController(), name = TextEditingController(), referralCode = TextEditingController();
  bool register = false, busy = false, obscure = true;

  Future<void> submit() async {
    final e = email.text.trim(), p = password.text, n = name.text.trim(), r = referralCode.text.trim().toUpperCase();
    if (!e.contains('@') || p.length < 6 || (register && n.isEmpty)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete the fields. Password must be at least 6 characters.'))); return; }
    setState(() => busy = true);
    try {
      if (register) {
        if (r.isNotEmpty) {
          final valid = await Supabase.instance.client.rpc('validate_referral_code', params: {'p_referral_code': r});
          if (valid != true) {
            throw Exception('Invalid referral code.');
          }
        }
        final response = await Supabase.instance.client.auth.signUp(email: e, password: p, data: {'full_name': n, 'referral_code': r});
        if (response.session != null) { await SupabaseService.logActivity(action: 'register_success', entityType: 'auth'); }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.session == null ? 'Account created. Check your email if verification is enabled.' : 'Account created successfully.')));
      } else { await Supabase.instance.client.auth.signInWithPassword(email: e, password: p); await SupabaseService.logActivity(action: 'login_success', entityType: 'auth'); }
    } on AuthException catch (x) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(x, fallback: x.message)))); }
    catch (x) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(x)))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override void dispose() { email.dispose(); password.dispose(); name.dispose(); referralCode.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(body: ZenexGlowBackground(safeArea: false, child: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 28, 20, 30), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Column(children: [
    const ZenexLogo(size: 78), const SizedBox(height: 12),
    RichText(text: const TextSpan(children: [TextSpan(text: 'Zenex', style: TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900)), TextSpan(text: 'Pay', style: TextStyle(color: kPink, fontSize: 31, fontWeight: FontWeight.w900))])),
    const SizedBox(height: 5), const Text('WORK  •  EARN  •  GROW', style: TextStyle(color: Colors.white54, letterSpacing: 1.5, fontSize: 9, fontWeight: FontWeight.w700)),
    const SizedBox(height: 24),
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF0B1530).withOpacity(.94), borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFF2B58A1)), boxShadow: [BoxShadow(color: kPurple.withOpacity(.12), blurRadius: 30)]), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(register ? 'Create your account' : 'Welcome Back', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5), Text(register ? 'Start your earning journey.' : 'Sign in to continue your earning journey.', style: TextStyle(color: zenexMutedText(context), fontSize: 12)),
      const SizedBox(height: 20),
      if (register) ...[TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded))), const SizedBox(height: 12)],
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email or Phone', prefixIcon: Icon(Icons.alternate_email_rounded))),
      const SizedBox(height: 12),
      TextField(controller: password, obscureText: obscure, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
      if (!register) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())), child: const Text('Forgot Password?'))),
      if (register) ...[const SizedBox(height: 4), TextField(controller: referralCode, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Referral Code (Optional)', prefixIcon: Icon(Icons.card_giftcard_rounded))),],
      const SizedBox(height: 16),
      NeonButton(label: busy ? 'Please wait...' : register ? 'Create Account' : 'Login', onPressed: busy ? null : submit),
      const SizedBox(height: 7),
      TextButton(onPressed: busy ? null : () => setState(() { register = !register; if (!register) referralCode.clear(); }), child: Text(register ? 'Already have an account? Login' : 'Don’t have an account? Register')),
    ])),
    const SizedBox(height: 14), Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.verified_user_outlined, size: 14, color: Colors.white38), SizedBox(width: 6), Text('Secure account  •  Genuine tasks  •  Server-controlled wallet', style: TextStyle(color: Colors.white38, fontSize: 9))]),
  ])))))));
}
