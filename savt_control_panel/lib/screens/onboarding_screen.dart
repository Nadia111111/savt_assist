// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_spacing.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/responsive_layout.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

    final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Добавьте проект',
      'subtitle': 'Отсканируйте QR-код проекта, чтобы получить доступ к шкафам управления.',
      'icon': Icons.qr_code_scanner,
    },
    {
      'title': 'Задавайте вопросы',
      'subtitle': 'Используйте наш умный чат поддержки для решения любых технических вопросов.',
      'icon': Icons.chat_bubble_outline,
    },
    {
      'title': 'Следите за гарантией',
      'subtitle': 'Получайте своевременные уведомления об истечении гарантийного срока и важных событиях.',
      'icon': Icons.notifications_active_outlined,
    },
    {
      'title': 'Все документы в одном месте',
      'subtitle': 'Удобный доступ к технической документации ШУ и общей базе знаний.',
      'icon': Icons.folder_shared_outlined,
    },
  ];

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_onboarding_shown', true);

    if (mounted) {
      // Направляемся сразу на страницу входа/регистрации
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      useTransparentBody: true,
      body: ResponsiveContainer(
        maxWidth: 600,
        child: SafeArea(
          child: Column(
            children: [
              // Header action: Skip Button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm, right: AppSpacing.sm),
                  child: _currentPage < _slides.length - 1
                      ? TextButton(
                          onPressed: _finishOnboarding,
                          child: const Text(
                            'Пропустить',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox(height: 48),
                ),
              ),

              // PageView Slides
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) {
                    setState(() => _currentPage = idx);
                  },
                  itemCount: _slides.length,
                  itemBuilder: (context, idx) {
                    final slide = _slides[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Illustrative Icon Card
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              slide['icon'] as IconData,
                              color: Colors.white,
                              size: 72,
                            ),
                          ),
                           const SizedBox(height: AppSpacing.xl),
                           // Title
                          Text(
                            slide['title'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                           const SizedBox(height: AppSpacing.base),
                           // Subtitle
                          Text(
                            slide['subtitle'] as String,
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Indicator and Button Panel
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Dots Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                          width: _currentPage == index ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white38,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                     const SizedBox(height: AppSpacing.xl),
 
                     // Primary Button (Start or Next)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF054582),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          if (_currentPage < _slides.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _finishOnboarding();
                          }
                        },
                        child: Text(
                          _currentPage == _slides.length - 1
                              ? 'Начать пользоваться'
                              : 'Далее',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

