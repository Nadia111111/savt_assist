import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../theme/app_spacing.dart';

class DrawingLine {
  final List<Offset> points;
  final Color color;
  final double width;

  DrawingLine({
    required this.points,
    required this.color,
    required this.width,
  });
}

class ImageEditorScreen extends StatefulWidget {
  final File? imageFile;
  final Uint8List? imageBytes;

  const ImageEditorScreen({
    super.key,
    this.imageFile,
    this.imageBytes,
  });

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<DrawingLine> _lines = [];
  final List<DrawingLine> _undoneLines = [];
  
  Color _selectedColor = Colors.red;
  double _selectedWidth = 4.0;
  bool _isDrawing = false;

  final List<Color> _palette = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.white,
    Colors.black,
  ];

  void _undo() {
    if (_lines.isNotEmpty) {
      setState(() {
        _undoneLines.add(_lines.removeLast());
      });
    }
  }

  void _redo() {
    if (_undoneLines.isNotEmpty) {
      setState(() {
        _lines.add(_undoneLines.removeLast());
      });
    }
  }

  void _clear() {
    if (_lines.isNotEmpty) {
      setState(() {
        _undoneLines.addAll(_lines);
        _lines.clear();
      });
    }
  }

  Future<void> _save() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final pngBytes = byteData.buffer.asUint8List();
        if (mounted) {
          Navigator.pop(context, pngBytes);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения рисунка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Редактор', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _lines.isNotEmpty ? _undo : null,
            tooltip: 'Отменить',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _undoneLines.isNotEmpty ? _redo : null,
            tooltip: 'Вернуть',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _lines.isNotEmpty ? _clear : null,
            tooltip: 'Очистить все',
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.greenAccent),
            onPressed: _save,
            tooltip: 'Готово',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _repaintKey,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.imageFile != null)
                      Image.file(widget.imageFile!, fit: BoxFit.contain)
                    else if (widget.imageBytes != null)
                      Image.memory(widget.imageBytes!, fit: BoxFit.contain)
                    else
                      const SizedBox(width: 300, height: 300, child: Icon(Icons.image, size: 100)),
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onPanStart: (details) {
                              setState(() {
                                _isDrawing = true;
                                _undoneLines.clear();
                                _lines.add(DrawingLine(
                                  points: [details.localPosition],
                                  color: _selectedColor,
                                  width: _selectedWidth,
                                ));
                              });
                            },
                            onPanUpdate: (details) {
                              if (_isDrawing && _lines.isNotEmpty) {
                                final localPos = details.localPosition;
                                final clampedPos = Offset(
                                  localPos.dx.clamp(0.0, constraints.maxWidth),
                                  localPos.dy.clamp(0.0, constraints.maxHeight),
                                );
                                setState(() {
                                  _lines.last.points.add(clampedPos);
                                });
                              }
                            },
                            onPanEnd: (_) {
                              _isDrawing = false;
                            },
                            child: CustomPaint(
                              painter: DrawingPainter(lines: _lines),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.base, horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.brush, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _selectedColor,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: _selectedColor.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _selectedWidth,
                    min: 1.0,
                    max: 20.0,
                    onChanged: (val) {
                      setState(() {
                        _selectedWidth = val;
                      });
                    },
                  ),
                ),
              ),
              Text(
                '${_selectedWidth.toInt()} px',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          gapH12,
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _palette.length,
              itemBuilder: (context, index) {
                final color = _palette[index];
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white24,
                        width: isSelected ? 3.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingLine> lines;

  DrawingPainter({required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = line.width
        ..style = PaintingStyle.stroke;

      if (line.points.length == 1) {
        canvas.drawCircle(line.points.first, line.width / 2, paint..style = PaintingStyle.fill);
      } else {
        for (int i = 0; i < line.points.length - 1; i++) {
          canvas.drawLine(line.points[i], line.points[i + 1], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return true;
  }
}
