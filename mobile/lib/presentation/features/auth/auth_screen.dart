import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  static const _baseLanguageOptions = ['Amharic', 'Afaan Oromoo', 'English'];

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isRegister = false;
  String? _error;
  String _nativeLanguage = 'Amharic';

  @override
  void initState() {
    super.initState();
    _nativeLanguage = ref.read(onboardingNativeLanguageProvider);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (_isRegister && password.length < 8) {
      return 'Use at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (!_isRegister) {
      return null;
    }
    if ((value ?? '').isEmpty) {
      return 'Confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    try {
      final auth = ref.read(authStateProvider.notifier);
      if (_isRegister) {
        await auth.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          nativeLanguage: _nativeLanguage,
          targetLanguage: ref.read(onboardingTargetLanguageProvider),
          dailyXpGoal: 20,
        );
      } else {
        await auth.login(
            _emailController.text.trim(), _passwordController.text);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.response?.data.toString() ?? 'Authentication failed';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Authentication failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final loading = auth.isLoading;
    final title = _isRegister ? 'Create Account' : 'Welcome Back';
    final subtitle = _isRegister
        ? 'Start your French journey with personalized lessons.'
        : 'Log in and continue your streak.';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0E2A1F), Color(0xFF154733), Color(0xFFF4EFE2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height - 36,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Fluentian',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: const Color(0xFFD9E6DF)),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _AuthModeButton(
                            label: 'Login',
                            selected: !_isRegister,
                            onTap: loading
                                ? null
                                : () {
                                    setState(() {
                                      _isRegister = false;
                                      _error = null;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AuthModeButton(
                            label: 'Create Account',
                            selected: _isRegister,
                            onTap: loading
                                ? null
                                : () {
                                    setState(() {
                                      _isRegister = true;
                                      _error = null;
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x2A000000),
                          blurRadius: 22,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: _validateEmail,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'name@example.com',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            textInputAction: _isRegister
                                ? TextInputAction.next
                                : TextInputAction.done,
                            validator: _validatePassword,
                            onFieldSubmitted: (_) {
                              if (!_isRegister && !loading) {
                                _submit();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(14)),
                              ),
                            ),
                          ),
                          if (_isRegister) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              validator: _validateConfirmPassword,
                              decoration: const InputDecoration(
                                labelText: 'Confirm password',
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(14)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: _nativeLanguage,
                              decoration: const InputDecoration(
                                labelText: 'Base language',
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(14)),
                                ),
                              ),
                              items: _baseLanguageOptions
                                  .map(
                                    (lang) => DropdownMenuItem<String>(
                                      value: lang,
                                      child: Text(lang),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                final selected = value ?? 'Amharic';
                                setState(() {
                                  _nativeLanguage = selected;
                                });
                                ref
                                    .read(onboardingNativeLanguageProvider
                                        .notifier)
                                    .state = selected;
                              },
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEFEC),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFFFC9BF)),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFF8A1F0A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F5D3F),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: loading ? null : _submit,
                              child: loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isRegister ? 'Create account' : 'Log in',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              setState(() {
                                _isRegister = !_isRegister;
                                _error = null;
                              });
                            },
                      child: Text(
                        _isRegister
                            ? 'Already have an account? Log in'
                            : 'New here? Create account',
                        style: const TextStyle(color: Color(0xFFF4EFE2)),
                      ),
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

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? const Color(0xFF0F5D3F)
                      : const Color(0xFFE8F0EB),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}
