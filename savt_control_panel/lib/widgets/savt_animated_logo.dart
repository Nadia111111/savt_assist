import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'savt_logo_data.dart';

/// Анимированный логотип SAVT с адаптивным масштабированием и идеальным центрированием:
/// 1. Буква S появляется по центру с упругим масштабированием (scale 0.35 -> 1.0).
/// 2. Буква S плавно отъезжает влево, и из неё выплывают буквы AVT.
/// 3. Полный логотип SAVT фиксируется на экране (равные отступы слева и справа!).
/// 4. Буквы AVT ныряют обратно в букву S.
/// 5. Буква S возвращается в центр и завершает цикл.
class SavtAnimatedLogo extends StatefulWidget {
  final double height;
  final bool loop;
  final Duration duration;
  final VoidCallback? onCycleCompleted;

  const SavtAnimatedLogo({
    super.key,
    this.height = 68,
    this.loop = true,
    this.duration = const Duration(milliseconds: 4600),
    this.onCycleCompleted,
  });

  @override
  State<SavtAnimatedLogo> createState() => _SavtAnimatedLogoState();
}

class _SavtAnimatedLogoState extends State<SavtAnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCycleCompleted?.call();
        if (mounted && widget.loop) {
          _controller.forward(from: 0.0);
        }
      }
    });

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant SavtAnimatedLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loop != oldWidget.loop) {
      if (widget.loop && !_controller.isAnimating) {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Гарантируем равные безопасные отступы слева и справа (минимум по 28px с каждого края)
        final double maxAvailableW = constraints.maxWidth.isFinite
            ? constraints.maxWidth - 56.0
            : 320.0;

        // Истинные пропорции логотипа SAVT (ширина 399, высота 86)
        const double logoAspectRatio = 399.0 / 86.0;
        final double idealW = widget.height * logoAspectRatio;
        final double totalW = idealW > maxAvailableW ? maxAvailableW : idealW;
        final double h = totalW / logoAspectRatio;

        // Точные доли каждой части:
        // S = 105px, зазор = 5px, AVT = 289px (105 + 5 + 289 = 399)
        final double sW = totalW * (105.0 / 399.0);
        final double avtW = totalW * (289.0 / 399.0);
        final double gap = totalW * (5.0 / 399.0);

        // В собранном состоянии:
        // Левый край буквы S = 0.0
        // Правый край буквы T = sW + gap + avtW = totalW.
        // Так как контейнер totalW отцентрован на экране, расстояние от левого экрана до S
        // и от правого экрана до T ВСЕГДА СТРОГО ОДИНАКОВО!
        final double sCenterX = (totalW - sW) / 2.0;
        const double sLeftX = 0.0;
        final double avtTargetX = sW + gap;

        return Center(
          child: SizedBox(
            width: totalW,
            height: h,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final double p = _controller.value;

                double currentSX;
                double currentSScale = 1.0;
                double currentSOpacity = 1.0;

                double currentAvtX;
                double currentAvtOpacity = 0.0;
                bool showAvt = false;

                if (p < 0.18) {
                  // Фаза 1: S плавно и красиво появляется по центру экрана (0 - 828 мс)
                  final double t = (p / 0.18).clamp(0.0, 1.0);
                  final double curvedT = Curves.easeOutBack.transform(t);

                  currentSX = sCenterX;
                  currentSScale = 0.35 + 0.65 * curvedT;
                  currentSOpacity = (t * 2.0).clamp(0.0, 1.0);
                  currentAvtX = sCenterX + sW - avtW;
                  showAvt = false;
                } else if (p < 0.44) {
                  // Фаза 2: S плавно отъезжает влево, AVT величаво выплывает из S (828 - 2024 мс, длительность ~1.2 сек)
                  final double t = ((p - 0.18) / 0.26).clamp(0.0, 1.0);
                  final double curvedT = Curves.easeOutCubic.transform(t);

                  currentSX = sCenterX + (sLeftX - sCenterX) * curvedT;
                  currentSScale = 1.0;
                  currentSOpacity = 1.0;

                  showAvt = true;
                  final double hiddenAvtX = currentSX + sW - avtW;
                  currentAvtX = hiddenAvtX + (avtTargetX - hiddenAvtX) * curvedT;
                  currentAvtOpacity = (curvedT * 1.5).clamp(0.0, 1.0);
                } else if (p < 0.74) {
                  // Фаза 3: Полный логотип зафиксирован и чётко виден на экране (2024 - 3404 мс, комфортные ~1.4 сек!)
                  currentSX = sLeftX;
                  currentSScale = 1.0;
                  currentSOpacity = 1.0;

                  showAvt = true;
                  currentAvtX = avtTargetX;
                  currentAvtOpacity = 1.0;
                } else if (p < 0.92) {
                  // Фаза 4: AVT плавно ныряет обратно в S, S возвращается в центр (3404 - 4232 мс, ~830 мс)
                  final double t = ((p - 0.74) / 0.18).clamp(0.0, 1.0);
                  final double curvedT = Curves.easeInOutCubic.transform(t);

                  currentSX = sLeftX + (sCenterX - sLeftX) * curvedT;
                  currentSScale = 1.0;
                  currentSOpacity = 1.0;

                  showAvt = true;
                  final double hiddenAvtX = currentSX + sW - avtW;
                  currentAvtX = avtTargetX + (hiddenAvtX - avtTargetX) * curvedT;
                  currentAvtOpacity = (1.0 - curvedT * 1.3).clamp(0.0, 1.0);
                } else {
                  // Фаза 5: Буквы уже внутри S, S делает мягкий «вдох» в центре и плавно завершает цикл (4232 - 4600 мс)
                  final double t = ((p - 0.92) / 0.08).clamp(0.0, 1.0);
                  final double breathe = 1.0 - 0.04 * math.sin(t * math.pi);

                  currentSX = sCenterX;
                  currentSScale = breathe;
                  currentSOpacity = 1.0;
                  currentAvtX = sCenterX + sW - avtW;
                  showAvt = false;
                }

                // Линия отсечения AVT: всё, что левее правой границы S, скрывается
                final double cutLeft = (currentSX + sW) - currentAvtX;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Буквы AVT (маскируются так, чтобы появляться строго из-за буквы S)
                    if (showAvt && currentAvtOpacity > 0.01)
                      Positioned(
                        left: currentAvtX,
                        top: 0,
                        width: avtW,
                        height: h,
                        child: ClipRect(
                          clipper: _AvtMaskClipper(cutLeft),
                          child: Opacity(
                            opacity: currentAvtOpacity,
                            child: Image.memory(
                              SavtLogoData.avtBytes,
                              width: avtW,
                              height: h,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/logo_letter_avt.png',
                                width: avtW,
                                height: h,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // 2. Буква S (расположена поверх AVT)
                    if (currentSOpacity > 0.01)
                      Positioned(
                        left: currentSX,
                        top: 0,
                        width: sW,
                        height: h,
                        child: Transform.scale(
                          scale: currentSScale,
                          alignment: Alignment.center,
                          child: Opacity(
                            opacity: currentSOpacity,
                            child: Image.memory(
                              SavtLogoData.sBytes,
                              width: sW,
                              height: h,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/logo_letter_s.png',
                                width: sW,
                                height: h,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _AvtMaskClipper extends CustomClipper<Rect> {
  final double cutLeft;
  const _AvtMaskClipper(this.cutLeft);

  @override
  Rect getClip(Size size) {
    final double left = cutLeft.clamp(0.0, size.width);
    return Rect.fromLTRB(left, -10, size.width, size.height + 10);
  }

  @override
  bool shouldReclip(covariant _AvtMaskClipper oldClipper) =>
      oldClipper.cutLeft != cutLeft;
}
