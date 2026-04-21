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
  static const _baseLanguageOptions = ['Amharic', 'English'];

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
    super.dispose();
  }

  Future<void> _submit() async {
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
      setState(() => _error = null);
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() =>
          _error = e.response?.data.toString() ?? 'Authentication failed');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'Authentication failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final loading = auth.isLoading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
              colors: [Color(0xFFDDF7E2), Color(0xFFFFF8EE)],
              radius: 1.3,
              center: Alignment.topLeft),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(_isRegister ? 'Create your account' : 'Welcome back',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)))),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)))),
                ),
                if (_isRegister) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _nativeLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Base language',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                    items: _baseLanguageOptions
                        .map((lang) =>
                            DropdownMenuItem(value: lang, child: Text(lang)))
                        .toList(),
                    onChanged: (value) {
                      final selected = value ?? 'Amharic';
                      setState(() => _nativeLanguage = selected);
                      ref
                          .read(onboardingNativeLanguageProvider.notifier)
                          .state = selected;
                    },
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const Spacer(),
                ElevatedButton(
                  onPressed: loading ? null : _submit,
                  child: Text(loading
                      ? 'Please wait...'
                      : (_isRegister ? 'Register' : 'Login')),
                ),
                TextButton(
                  onPressed: () => setState(() => _isRegister = !_isRegister),
                  child: Text(_isRegister
                      ? 'Already have an account? Login'
                      : 'No account? Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
