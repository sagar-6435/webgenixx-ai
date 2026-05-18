import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import 'auth_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 18.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _navigateToNextScreen();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Wait until auth loading is complete (tryAutoLogin finishes)
    int waited = 0;
    while (ref.read(authProvider).isLoading && waited < 5000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited += 100;
    }

    if (!mounted) return;

    final authState = ref.read(authProvider);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => authState.isAuthenticated
            ? const DashboardScreen()
            : const AuthScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.darkBackgroundGradient,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient subtle background glow rings
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryNeon.withOpacity(0.08),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondaryNeon.withOpacity(0.06),
                      blurRadius: 80,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
            
            // Core Logo & Branding Panel
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeInDown(
                  duration: const Duration(milliseconds: 1200),
                  child: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.obsidianCard,
                          border: Border.all(
                            color: AppTheme.primaryNeon.withOpacity(0.8),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryNeon.withOpacity(0.25),
                              blurRadius: _glowAnimation.value,
                              spreadRadius: _glowAnimation.value / 3,
                            ),
                            BoxShadow(
                              color: AppTheme.secondaryNeon.withOpacity(0.2),
                              blurRadius: _glowAnimation.value * 1.5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Vector design inside logo
                              const Icon(
                                Icons.offline_bolt_rounded,
                                size: 55,
                                color: AppTheme.secondaryNeon,
                              ),
                              Transform.rotate(
                                angle: 0.5,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.textWhite.withOpacity(0.1),
                                      width: 1,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                FadeInUp(
                  duration: const Duration(milliseconds: 1000),
                  delay: const Duration(milliseconds: 400),
                  child: Text(
                    'WEBGENIXX AI',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      foreground: Paint()
                        ..shader = AppTheme.primaryGradient.createShader(
                          const Rect.fromLTWH(0.0, 0.0, 300.0, 70.0),
                        ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeInUp(
                  duration: const Duration(milliseconds: 1000),
                  delay: const Duration(milliseconds: 700),
                  child: const Text(
                    'Automate Your Sales Calls',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            
            // Bottom Credits loader
            Positioned(
              bottom: 60,
              child: FadeIn(
                duration: const Duration(seconds: 1),
                delay: const Duration(seconds: 1),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 2,
                      child: LinearProgressIndicator(
                        backgroundColor: AppTheme.borderBlue,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryNeon),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'AI SALES AGENT ENGINE',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: AppTheme.textMuted.withOpacity(0.6),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
