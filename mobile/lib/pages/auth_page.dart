import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    if (emailText.isEmpty ||
        passwordText.length < 6 ||
        (register && nameText.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all fields. Password must be at least 6 characters.',
          ),
        ),
      );
      return;
    }

    setState(() => busy = true);

    try {
      if (register) {
        final response =
            await Supabase.instance.client.auth.signUp(
          email: emailText,
          password: passwordText,
          data: {
            'full_name': nameText,

            // Referral code পাঠানো হচ্ছে Supabase trigger-এ
            'referral_code': referralText,
          },
        );

        if (!mounted) return;

        if (response.session == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created. Check your email if verification is enabled.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created successfully.',
              ),
            ),
          );
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: emailText,
          password: passwordText,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String message = '$e';

      if (message.toLowerCase().contains('invalid referral code')) {
        message = 'Invalid referral code.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 480,
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'ZenexPay',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Work • Earn • Grow',
                  ),

                  const SizedBox(height: 28),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            register
                                ? 'Create your account'
                                : 'Welcome back',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),

                          const SizedBox(height: 18),

                          // FULL NAME
                          if (register) ...[
                            TextField(
                              controller: name,
                              textCapitalization:
                                  TextCapitalization.words,
                              decoration:
                                  const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),
                          ],

                          // EMAIL
                          TextField(
                            controller: email,
                            keyboardType:
                                TextInputType.emailAddress,
                            decoration:
                                const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(
                                Icons.email_outlined,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // PASSWORD
                          TextField(
                            controller: password,
                            obscureText: obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    obscure = !obscure;
                                  });
                                },
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                          ),

                          // REFERRAL CODE
                          if (register) ...[
                            const SizedBox(height: 12),

                            TextField(
                              controller: referralCode,
                              textCapitalization:
                                  TextCapitalization.characters,
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    'Referral Code (Optional)',
                                hintText:
                                    'e.g. ZP2351C0F9',
                                prefixIcon: Icon(
                                  Icons.redeem_rounded,
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            const Text(
                              'Have a referral code? Enter it here.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed:
                                  busy ? null : submit,
                              child: Text(
                                busy
                                    ? 'Please wait...'
                                    : register
                                        ? 'Create Account'
                                        : 'Login',
                              ),
                            ),
                          ),

                          TextButton(
                            onPressed: busy
                                ? null
                                : () {
                                    setState(() {
                                      register = !register;

                                      // Register থেকে Login গেলে
                                      // referral code পরিষ্কার
                                      if (!register) {
                                        referralCode.clear();
                                      }
                                    });
                                  },
                            child: Text(
                              register
                                  ? 'Already have an account? Login'
                                  : 'New here? Create an account',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Real tasks • Honest proof • Secure wallet',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
