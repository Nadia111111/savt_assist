import 'dart:math';
import 'package:flutter/material.dart';

class FloatingCircle {
  double x;
  double y;
  double radius;
  double speedX;
  double speedY;
  double opacity;

  FloatingCircle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speedX,
    required this.speedY,
    required this.opacity,
  });
}

class AnimatedBackground extends StatefulWidget {
  final List<Color> gradientColors;
  const AnimatedBackground({
    super.key,
    this.gradientColors = const [Color(0xFF054582), Color(0xFF0a7ac2), Color(0xFFe0f2fe)],
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<FloatingCircle> _circles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Создаём плавающие круги
    for (int i = 0; i < 8; i++) {
      _circles.add(
        FloatingCircle(
          x: _random.nextDouble() * 400,
          y: _random.nextDouble() * 300,
          radius: 30 + _random.nextDouble() * 80,
          speedX: (_random.nextDouble() - 0.5) * 0.4,
          speedY: (_random.nextDouble() - 0.5) * 0.3,
          opacity: 0.03 + _random.nextDouble() * 0.06,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateCircles() {
    for (var circle in _circles) {
      circle.x += circle.speedX;
      circle.y += circle.speedY;

      if (circle.x < -100) circle.x = 500;
      if (circle.x > 500) circle.x = -100;
      if (circle.y < -100) circle.y = 400;
      if (circle.y > 400) circle.y = -100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        _updateCircles();
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradientColors,
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
          child: Stack(
            children: [
              ..._circles.map((circle) {
                return Positioned(
                  left: circle.x,
                  top: circle.y,
                  child: Container(
                    width: circle.radius * 2,
                    height: circle.radius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(circle.opacity),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(circle.opacity * 0.5),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              // Дополнительный большой blur-слой для глубины
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 100,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
