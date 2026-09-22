import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override State<AuthPage> createState() => _AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(); final password = TextEditingController(); final name = TextEditingController();
  bool register = false, busy = false, obscure = true;
  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.length < 6 || (register && name.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all fields. Password must be at least 6 characters.'))); return;
    }
    setState(() => busy = true);
    try {
      if (register) {
        await Supabase.instance.client.auth.signUp(email: email.text.trim(), password: password.text, data: {'full_name': name.text.trim()});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. Check your email if verification is enabled.')));
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      }
    } on AuthException catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(width: 76, height: 76, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 40)),
    const SizedBox(height: 18),
    const Text('ZenexPay', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6), const Text('Work • Earn • Grow', textAlign: TextAlign.center), const SizedBox(height: 28),
    Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(register ? 'Create your account' : 'Welcome back', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 18),
      if (register) ...[TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline))), const SizedBox(height: 12)],
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))), const SizedBox(height: 12),
      TextField(controller: password, obscureText: obscure, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility : Icons.visibility_off)))), const SizedBox(height: 18),
      SizedBox(height: 52, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Please wait...' : (register ? 'Create account' : 'Login')))),
      TextButton(onPressed: busy ? null : () => setState(() => register = !register), child: Text(register ? 'Already have an account? Login' : 'New here? Create an account')),
    ]))), const SizedBox(height: 16),
    const Text('Real tasks • Honest proof • Secure wallet', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
  ])))));
}
