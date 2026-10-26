// lib/widgets/draggable_floating_pill_overlay.dart
import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

/// Reusable overlay that wraps a screen body and displays a floating pill button
/// that can be dragged to any part of the screen, animates with elevation & scale,
/// morphs across screens via Hero, and persists its position across app restarts.
class DraggableFloatingPillOverlay extends StatefulWidget {
  final Widget child;
  final String storageKey;
  final String? heroTag;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isVisible;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? estimatedWidth;

  const DraggableFloatingPillOverlay({
    super.key,
    required this.child,
    required this.storageKey,
    this.heroTag,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isVisible = true,
    this.backgroundColor,
    this.foregroundColor,
    this.estimatedWidth,
  });

  @override
  State<DraggableFloatingPillOverlay> createState() =>
      _DraggableFloatingPillOverlayState();
}

class _DraggableFloatingPillOverlayState
    extends State<DraggableFloatingPillOverlay> {
  final GlobalKey _buttonKey = GlobalKey();
  Offset? _normalizedPosition;
  Offset? _currentPixelPosition;
  double? _measuredWidth;
  double? _measuredHeight;
  bool _isDragging = false;
  bool _hasMoved = false;
  double _accumulatedDelta = 0.0;

  @override
  void initState() {
    super.initState();
    _loadPosition();
    PreferencesService.fabPositionNotifier.addListener(_onFabPositionChanged);
  }

  @override
  void dispose() {
    PreferencesService.fabPositionNotifier.removeListener(_onFabPositionChanged);
    super.dispose();
  }

  void _onFabPositionChanged() {
    if (PreferencesService.lastUpdatedFabKey != null &&
        PreferencesService.lastUpdatedFabKey != widget.storageKey) {
      return;
    }
    if (mounted && !_isDragging) {
      setState(() {
        _loadPosition();
      });
    }
  }

  @override
  void didUpdateWidget(covariant DraggableFloatingPillOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageKey != widget.storageKey) {
      _loadPosition();
    }
    if (oldWidget.label != widget.label) {
      _measuredWidth = null;
      _measuredHeight = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureButton());
    }
  }

  void _loadPosition() {
    final saved = PreferencesService.getFabNormalizedPosition(widget.storageKey);
    if (saved != null) {
      _normalizedPosition = saved;
    } else {
      _normalizedPosition = const Offset(1.0, 1.0);
    }
  }

  void _measureButton() {
    final renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final size = renderBox.size;
      if (_measuredWidth != size.width || _measuredHeight != size.height) {
        if (mounted) {
          setState(() {
            _measuredWidth = size.width;
            _measuredHeight = size.height;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureButton());

    return LayoutBuilder(
      builder: (context, constraints) {
        final double buttonWidth =
            _measuredWidth ?? widget.estimatedWidth ?? 120.0;
        final double buttonHeight = _measuredHeight ?? 48.0;
        const double margin = 16.0;
        const double minX = margin;
        const double minY = margin;

        final double maxX = (constraints.maxWidth - buttonWidth - margin)
            .clamp(minX, double.infinity);
        final double maxY = (constraints.maxHeight - buttonHeight - margin)
            .clamp(minY, double.infinity);

        // Keep pixel position synchronized with normalized position when not dragging
        if (!_isDragging) {
          final double normX = _normalizedPosition?.dx ?? 1.0;
          final double normY = _normalizedPosition?.dy ?? 1.0;
          _currentPixelPosition = Offset(
            (minX + normX * (maxX - minX)).clamp(minX, maxX),
            (minY + normY * (maxY - minY)).clamp(minY, maxY),
          );
        } else if (_currentPixelPosition != null) {
          _currentPixelPosition = Offset(
            _currentPixelPosition!.dx.clamp(minX, maxX),
            _currentPixelPosition!.dy.clamp(minY, maxY),
          );
        }

        final double currentX = (_currentPixelPosition?.dx ?? maxX).clamp(minX, maxX);
        final double currentY = (_currentPixelPosition?.dy ?? maxY).clamp(minY, maxY);

        return Stack(
          children: [
            widget.child,
            if (widget.isVisible)
              Positioned(
                left: currentX,
                top: currentY,
                child: _buildDraggableButton(
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  maxPillWidth: constraints.maxWidth - (margin * 2),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDraggableButton({
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required double maxPillWidth,
  }) {
    final theme = Theme.of(context);
    
    // Подбираем яркий градиент и свечение
    final List<Color> gradientColors;
    final Color glowColor;

    if (widget.backgroundColor != null) {
      gradientColors = [
        widget.backgroundColor!,
        widget.backgroundColor!.withValues(alpha: 0.85),
      ];
      glowColor = widget.backgroundColor!;
    } else if (widget.label.toLowerCase().contains('рекламац')) {
      // Яркий кораллово-огненный градиент для рекламаций
      gradientColors = const [Color(0xFFFF5722), Color(0xFFE64A19)];
      glowColor = const Color(0xFFEA580C);
    } else if (widget.label.toLowerCase().contains('новая заявка')) {
      // Электрик лазурный градиент для новой заявки
      gradientColors = const [Color(0xFF0EA5E9), Color(0xFF0284C7)];
      glowColor = const Color(0xFF0284C7);
    } else {
      // Королевский синий ультрамарин для "Заявки" (Хаб)
      gradientColors = const [Color(0xFF3B82F6), Color(0xFF1D4ED8)];
      glowColor = const Color(0xFF2563EB);
    }

    final fgColor = widget.foregroundColor ?? Colors.white;

    Widget pill = KeyedSubtree(
      key: _buttonKey,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxPillWidth),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: _isDragging ? 0.55 : 0.38),
              blurRadius: _isDragging ? 18 : 12,
              offset: Offset(0, _isDragging ? 8 : 4),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    color: fgColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fgColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.heroTag != null) {
      pill = Hero(
        tag: widget.heroTag!,
        flightShuttleBuilder: (
          flightContext,
          animation,
          flightDirection,
          fromHeroContext,
          toHeroContext,
        ) {
          return Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: toHeroContext.widget,
            ),
          );
        },
        child: pill,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        _accumulatedDelta = 0.0;
        setState(() {
          _isDragging = true;
          _hasMoved = false;
        });
      },
      onPanUpdate: (details) {
        _accumulatedDelta += details.delta.distance;
        if (_accumulatedDelta > 5.0) {
          _hasMoved = true;
        }

        final cur = _currentPixelPosition ?? Offset(maxX, maxY);
        final newX = (cur.dx + details.delta.dx).clamp(minX, maxX);
        final newY = (cur.dy + details.delta.dy).clamp(minY, maxY);

        setState(() {
          _currentPixelPosition = Offset(newX, newY);
        });
      },
      onPanEnd: (_) {
        if (maxX > minX && maxY > minY && _currentPixelPosition != null) {
          final nX =
              ((_currentPixelPosition!.dx - minX) / (maxX - minX)).clamp(0.0, 1.0);
          final nY =
              ((_currentPixelPosition!.dy - minY) / (maxY - minY)).clamp(0.0, 1.0);
          _normalizedPosition = Offset(nX, nY);
          PreferencesService.saveFabNormalizedPosition(widget.storageKey, nX, nY);
        }
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isDragging = false;
              _hasMoved = false;
            });
          }
        });
      },
      onPanCancel: () {
        if (maxX > minX && maxY > minY && _currentPixelPosition != null) {
          final nX =
              ((_currentPixelPosition!.dx - minX) / (maxX - minX)).clamp(0.0, 1.0);
          final nY =
              ((_currentPixelPosition!.dy - minY) / (maxY - minY)).clamp(0.0, 1.0);
          _normalizedPosition = Offset(nX, nY);
          PreferencesService.saveFabNormalizedPosition(widget.storageKey, nX, nY);
        }
        setState(() {
          _isDragging = false;
          _hasMoved = false;
        });
      },
      onTap: () {
        if (!_hasMoved) {
          widget.onTap();
        }
      },
      child: AnimatedScale(
        scale: _isDragging ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: pill,
      ),
    );
  }
}
