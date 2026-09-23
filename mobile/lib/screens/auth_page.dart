import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reset_password_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final referralCode = TextEditingController();

  bool register = false;
  bool busy = false;
  bool obscure = true;

  Future<void> submit() async {
    final emailText = email.text.trim();
    final passwordText = password.text;
    final nameText = name.text.trim();
    final referralText = referralCode.text.trim().toUpperCase();

    if (!emailText.contains('@') ||
        passwordText.length < 6 ||
        (register && nameText.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the fields. Password must be at least 6 characters.'),
        ),
      );
      return;
    }

    setState(() => busy = true);
    try {
      if (register) {
        final response = await Supabase.instance.client.auth.signUp(
          email: emailText,
          password: passwordText,
          data: {
            'full_name': nameText,
            'referral_code': referralText,
          },
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.session == null
                  ? 'Account created. Check your email if verification is enabled.'
                  : 'Account created successfully.',
            ),
          ),
        );
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: emailText,
          password: passwordText,
        );
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    referralCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surface,
              Color.alphaBlend(cs.primary.withOpacity(.10), cs.surface),
              Color.alphaBlend(cs.secondary.withOpacity(.08), cs.surface),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E7BFF), Color(0xFF7A42FF)],
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withOpacity(.30),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 42),
                    ),
                    const SizedBox(height: 18),
                    const Text('ZenexPay', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('WORK  •  EARN  •  GROW', style: TextStyle(letterSpacing: 1.5, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(.72),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: cs.outlineVariant.withOpacity(.45)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(register ? 'Create your account' : 'Welcome back', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(register ? 'Start earning with ZenexPay.' : 'Sign in to continue to your wallet.', style: TextStyle(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 20),
                          if (register) ...[
                            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline))),
                            const SizedBox(height: 12),
                          ],
                          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                          const SizedBox(height: 12),
                          TextField(
                            controller: password,
                            obscureText: obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility : Icons.visibility_off)),
                            ),
                          ),
                          if (!register) Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                              child: const Text('Forgot your password?'),
                            ),
                          ),
                          if (register) ...[
                            const SizedBox(height: 12),
                            TextField(controller: referralCode, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Referral Code (Optional)', prefixIcon: Icon(Icons.redeem_rounded))),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: busy ? null : submit,
                              child: Text(busy ? 'Please wait...' : register ? 'Create Account' : 'Sign In'),
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextButton(
                            onPressed: busy ? null : () => setState(() {
                              register = !register;
                              if (!register) referralCode.clear();
                            }),
                            child: Text(register ? 'Already have an account? Sign in' : 'New to ZenexPay? Create an account'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Secure account • Genuine tasks • Server-controlled wallet', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
