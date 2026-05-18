import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import 'dashboard_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLogin = true;
  bool _rememberMe = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final authNotifier = ref.read(authProvider.notifier);
    bool success = false;

    if (_isLogin) {
      success = await authNotifier.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } else {
      success = await authNotifier.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    }

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else if (mounted) {
      final errorMsg = ref.read(authProvider).error ?? 'Authentication failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBackgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Webgenixx Mini Glow Header
                  FadeInDown(
                    duration: const Duration(milliseconds: 800),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.obsidianCard,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.borderBlue),
                      ),
                      child: const Icon(
                        Icons.offline_bolt_rounded,
                        size: 40,
                        color: AppTheme.secondaryNeon,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  FadeInDown(
                    duration: const Duration(milliseconds: 800),
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      _isLogin ? 'Welcome Back' : 'Create Account',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeInDown(
                    duration: const Duration(milliseconds: 800),
                    delay: const Duration(milliseconds: 300),
                    child: const Text(
                      'AI Outbound Cold-Calling Platform',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Preloaded Admin Credentials Tooltip for smooth trial experience
                  if (_isLogin)
                    FadeIn(
                      duration: const Duration(milliseconds: 1000),
                      delay: const Duration(milliseconds: 500),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.all(12),
                        decoration: AppTheme.glassCardDecoration(
                          color: AppTheme.secondaryNeon.withOpacity(0.1),
                          borderColor: AppTheme.secondaryNeon.withOpacity(0.3),
                          radius: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppTheme.secondaryNeon, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                                  children: [
                                    const TextSpan(text: 'Quick Sandbox Credentials:\n', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryNeon)),
                                    const TextSpan(text: 'Email: '),
                                    TextSpan(
                                      text: 'founder@webgenixx.com\n',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textWhite),
                                    ),
                                    const TextSpan(text: 'Password: '),
                                    TextSpan(
                                      text: 'webgenixx123',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textWhite),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_all_outlined, color: AppTheme.secondaryNeon, size: 20),
                              onPressed: () {
                                _emailController.text = 'founder@webgenixx.com';
                                _passwordController.text = 'webgenixx123';
                              },
                              tooltip: 'Autofill credentials',
                            )
                          ],
                        ),
                      ),
                    ),

                  // Glassmorphic Auth Card Form
                  FadeInUp(
                    duration: const Duration(milliseconds: 800),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.glassCardDecoration(),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Sign Up Name Input
                            if (!_isLogin) ...[
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  hintText: 'Enter your name',
                                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email Input
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                hintText: 'Enter your email',
                                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password Input
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Enter password',
                                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textMuted),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: AppTheme.textMuted,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Remember Me & Forgot Password Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        activeColor: AppTheme.primaryNeon,
                                        checkColor: AppTheme.textWhite,
                                        side: const BorderSide(color: AppTheme.borderBlue),
                                        onChanged: (val) {
                                          setState(() {
                                            _rememberMe = val ?? true;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Remember Me',
                                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {},
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(color: AppTheme.secondaryNeon, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Main Action Submit Button
                            ElevatedButton(
                              onPressed: authState.isLoading ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: authState.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      _isLogin ? 'SIGN IN' : 'GET STARTED',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                            ),
                            const SizedBox(height: 16),

                            // Dynamic Switch Panel (Login vs Signup)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isLogin ? "Don't have an account? " : "Already have an account? ",
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isLogin = !_isLogin;
                                    });
                                  },
                                  child: Text(
                                    _isLogin ? 'Sign Up' : 'Sign In',
                                    style: const TextStyle(
                                      color: AppTheme.secondaryNeon,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
