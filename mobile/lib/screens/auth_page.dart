import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _isRegister = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final name = _nameController.text.trim();

      if (_isRegister) {
        final response = await _supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'full_name': name,
          },
        );

        if (!mounted) return;

        // If email confirmation is enabled, Supabase normally
        // returns no active session immediately after signup.
        if (response.session == null) {
          _showMessage(
            'Account created successfully. Please check your email to verify your account.',
          );
        } else {
          _showMessage(
            'Account created successfully. Welcome to ZenexPay!',
          );
        }
      } else {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;

        _showMessage('Login successful. Welcome back!');
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      _showMessage(
        _friendlyAuthError(e.message),
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Something went wrong. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyAuthError(String message) {
    final text = message.toLowerCase();

    if (text.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }

    if (text.contains('email not confirmed')) {
      return 'Please verify your email before logging in.';
    }

    if (text.contains('user already registered')) {
      return 'This email is already registered. Please login instead.';
    }

    if (text.contains('password should be at least')) {
      return 'Password must be at least 6 characters.';
    }

    if (text.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }

    if (text.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    return message;
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      );
  }

  void _toggleMode() {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isRegister = !_isRegister;

      // Clear registration-only field when returning to login.
      if (!_isRegister) {
        _nameController.clear();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 480,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // --------------------------------------------------
                      // LOGO
                      // --------------------------------------------------
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary,
                              colors.secondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(
                                alpha: 0.22,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'ZenexPay',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Work • Earn • Grow',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.60),
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // --------------------------------------------------
                      // AUTH CARD
                      // --------------------------------------------------
                      Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _isRegister
                                    ? 'Create your account'
                                    : 'Welcome back',
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                _isRegister
                                    ? 'Join ZenexPay and start earning.'
                                    : 'Login to continue to your account.',
                                style: TextStyle(
                                  color: theme
                                      .colorScheme.onSurface
                                      .withValues(alpha: 0.60),
                                ),
                              ),

                              const SizedBox(height: 22),

                              // ------------------------------------------------
                              // NAME
                              // ------------------------------------------------
                              if (_isRegister) ...[
                                TextFormField(
                                  controller: _nameController,
                                  textCapitalization:
                                      TextCapitalization.words,
                                  textInputAction:
                                      TextInputAction.next,
                                  enabled: !_isLoading,
                                  decoration: const InputDecoration(
                                    labelText: 'Full name',
                                    hintText: 'Enter your full name',
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (!_isRegister) return null;

                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Please enter your name';
                                    }

                                    if (value.trim().length < 2) {
                                      return 'Name is too short';
                                    }

                                    return null;
                                  },
                                ),

                                const SizedBox(height: 14),
                              ],

                              // ------------------------------------------------
                              // EMAIL
                              // ------------------------------------------------
                              TextFormField(
                                controller: _emailController,
                                enabled: !_isLoading,
                                keyboardType:
                                    TextInputType.emailAddress,
                                textInputAction:
                                    TextInputAction.next,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'Enter your email',
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                  ),
                                ),
                                validator: (value) {
                                  final email =
                                      value?.trim() ?? '';

                                  if (email.isEmpty) {
                                    return 'Please enter your email';
                                  }

                                  final emailRegex = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  );

                                  if (!emailRegex.hasMatch(email)) {
                                    return 'Please enter a valid email';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              // ------------------------------------------------
                              // PASSWORD
                              // ------------------------------------------------
                              TextFormField(
                                controller: _passwordController,
                                enabled: !_isLoading,
                                obscureText: _obscurePassword,
                                textInputAction:
                                    TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_isLoading) {
                                    _submit();
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Enter your password',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null ||
                                      value.isEmpty) {
                                    return 'Please enter your password';
                                  }

                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 22),

                              // ------------------------------------------------
                              // SUBMIT BUTTON
                              // ------------------------------------------------
                              SizedBox(
                                height: 54,
                                child: FilledButton(
                                  onPressed:
                                      _isLoading ? null : _submit,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _isRegister
                                              ? 'Create account'
                                              : 'Login',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight:
                                                FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // ------------------------------------------------
                              // SWITCH LOGIN / REGISTER
                              // ------------------------------------------------
                              TextButton(
                                onPressed:
                                    _isLoading ? null : _toggleMode,
                                child: Text(
                                  _isRegister
                                      ? 'Already have an account? Login'
                                      : 'New here? Create an account',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 17,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Secure account • Real tasks • Real earnings',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text('Work • Earn • Grow'),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            register ? 'Create your account' : 'Welcome back',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (register) ...[
                            TextField(
                              controller: name,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: password,
                            obscureText: obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => obscure = !obscure),
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: busy ? null : submit,
                              child: Text(
                                busy
                                    ? 'Please wait...'
                                    : (register ? 'Create account' : 'Login'),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() => register = !register),
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
                    style: TextStyle(color: Colors.grey),
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
