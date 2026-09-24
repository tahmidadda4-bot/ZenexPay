import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reset_password_page.dart';
import '../zenex_ui.dart';

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
      _message('Please complete all required fields. Password must be at least 6 characters.');
      return;
    }

    FocusScope.of(context).unfocus();
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
        _message(
          response.session == null
              ? 'Account created. Check your email if verification is enabled.'
              : 'Account created successfully.',
        );
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: emailText,
          password: passwordText,
        );
      }
    } on AuthException catch (e) {
      if (mounted) _message(e.message);
    } catch (e) {
      if (mounted) _message('$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleMode(bool value) {
    if (busy) return;
    setState(() {
      register = value;
      if (!register) referralCode.clear();
    });
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? Colors.white60 : Colors.black54;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || busy) return;
        if (register) {
          setState(() => register = false);
        } else {
          _message('Press back again is disabled on the sign-in screen.');
        }
      },
      child: Scaffold(
        body: ZenexPageBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 34),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 58),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _BrandHeader(dark: dark),
                            const SizedBox(height: 26),
                            _AuthCard(
                              dark: dark,
                              muted: muted,
                              register: register,
                              busy: busy,
                              name: name,
                              email: email,
                              password: password,
                              referralCode: referralCode,
                              obscure: obscure,
                              onToggleObscure: () => setState(() => obscure = !obscure),
                              onSubmit: submit,
                              onForgot: busy
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ForgotPasswordPage(),
                                        ),
                                      ),
                              onModeChanged: _toggleMode,
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield_outlined, size: 15, color: muted),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    'Secure account • Genuine tasks • Server-controlled wallet',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11.5, color: muted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final bool dark;
  const _BrandHeader({required this.dark});

  @override
  Widget build(BuildContext context) {
    final muted = dark ? Colors.white60 : Colors.black54;

    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kCyan, kBlue, kPurple, kPink],
            ),
            borderRadius: BorderRadius.circular(27),
            boxShadow: [
              BoxShadow(color: kPurple.withOpacity(.32), blurRadius: 32, spreadRadius: 2),
              BoxShadow(color: kCyan.withOpacity(.12), blurRadius: 50, spreadRadius: 5),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 42,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ZenexPay',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -.9,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'WORK  •  EARN  •  GROW',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.1,
            color: muted,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: kCyan.withOpacity(.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: kCyan.withOpacity(.18)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: kCyan),
              SizedBox(width: 6),
              Text(
                'YOUR EARNING JOURNEY STARTS HERE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                  color: kCyan,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  final bool dark;
  final Color muted;
  final bool register;
  final bool busy;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController referralCode;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback? onForgot;
  final ValueChanged<bool> onModeChanged;

  const _AuthCard({
    required this.dark,
    required this.muted,
    required this.register,
    required this.busy,
    required this.name,
    required this.email,
    required this.password,
    required this.referralCode,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onForgot,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: dark ? Colors.white.withOpacity(.055) : Colors.white.withOpacity(.90),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: dark ? Colors.white.withOpacity(.11) : Colors.black.withOpacity(.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? .28 : .08),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: dark ? Colors.black.withOpacity(.20) : Colors.black.withOpacity(.035),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: dark ? Colors.white.withOpacity(.06) : Colors.black.withOpacity(.05)),
                ),
                child: Row(
                  children: [
                    _ModeButton(
                      selected: !register,
                      label: 'Sign In',
                      icon: Icons.login_rounded,
                      onTap: () => onModeChanged(false),
                    ),
                    _ModeButton(
                      selected: register,
                      label: 'Create Account',
                      icon: Icons.person_add_alt_1_rounded,
                      onTap: () => onModeChanged(true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                register ? 'Create your ZenexPay account' : 'Welcome back',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.4),
              ),
              const SizedBox(height: 6),
              Text(
                register
                    ? 'Set up your account and start completing tasks.'
                    : 'Sign in to continue your earning journey.',
                style: TextStyle(color: muted, height: 1.35),
              ),
              const SizedBox(height: 20),
              if (register) ...[
                _Field(
                  controller: name,
                  label: 'Full name',
                  hint: 'Enter your full name',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
              ],
              _Field(
                controller: email,
                label: 'Email address',
                hint: 'you@example.com',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: password,
                label: 'Password',
                hint: 'Minimum 6 characters',
                icon: Icons.lock_outline_rounded,
                obscureText: obscure,
                suffix: IconButton(
                  onPressed: onToggleObscure,
                  icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  tooltip: obscure ? 'Show password' : 'Hide password',
                ),
              ),
              if (!register) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onForgot,
                    child: const Text('Forgot password?'),
                  ),
                ),
              ],
              if (register) ...[
                const SizedBox(height: 12),
                _Field(
                  controller: referralCode,
                  label: 'Referral code (optional)',
                  hint: 'Enter code if you have one',
                  icon: Icons.redeem_rounded,
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kBlue, kPurple, kPink],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: kPurple.withOpacity(.25), blurRadius: 24, offset: const Offset(0, 9)),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: busy ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(strokeWidth: 2.3, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(register ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded),
                              const SizedBox(width: 9),
                              Text(register ? 'Create My Account' : 'Continue to ZenexPay'),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Divider(color: dark ? Colors.white12 : Colors.black12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('SECURE ACCESS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: muted)),
                  ),
                  Expanded(child: Divider(color: dark ? Colors.white12 : Colors.black12)),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MiniTrust(icon: Icons.verified_user_outlined, text: 'Protected'),
                  const SizedBox(width: 14),
                  _MiniTrust(icon: Icons.lock_outline_rounded, text: 'Encrypted'),
                  const SizedBox(width: 14),
                  _MiniTrust(icon: Icons.cloud_done_outlined, text: 'Cloud synced'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeButton({required this.selected, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [kBlue, kPurple])
              : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [BoxShadow(color: kPurple.withOpacity(.20), blurRadius: 14, offset: const Offset(0, 5))]
              : null,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
      ),
    );
  }
}

class _MiniTrust extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniTrust({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kCyan),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)),
        ],
      );
}
