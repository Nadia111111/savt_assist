import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String? voiceUrl;
  final String? voicePath;
  final bool isOwn;
  final String? initialTranscription;
  final Future<String?> Function()? onTranscribe;
  final Future<String?> Function()? onGetLocalAudio;
  final VoidCallback? onDownload;

  final Color? activeColor;
  final bool transparentBackground;

  const VoiceMessagePlayer({
    super.key,
    this.voiceUrl,
    this.voicePath,
    required this.isOwn,
    this.initialTranscription,
    this.onTranscribe,
    this.onGetLocalAudio,
    this.onDownload,
    this.activeColor,
    this.transparentBackground = false,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;

  bool _isTranscribing = false;
  String? _transcriptionText;
  bool _showTranscription = false;

  String? _cachedLocalPath;
  bool _isLoadingAudio = false;

  final List<double> _waveformHeights = [];

  @override
  void initState() {
    super.initState();
    _cachedLocalPath = widget.voicePath;
    _transcriptionText = widget.initialTranscription;
    _showTranscription = _transcriptionText != null && _transcriptionText!.isNotEmpty;
    
    // Генерируем красивую гладкую волну в форме холма (bell curve) с легким шумом
    final random = Random();
    const count = 32;
    for (int i = 0; i < count; i++) {
      double ratio = i / (count - 1);
      double waveHeight = sin(ratio * pi); // холм от 0 до 1
      double baseHeight = 4.0 + 16.0 * waveHeight;
      double noise = random.nextDouble() * 4.0;
      _waveformHeights.add(baseHeight + noise);
    }

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      }
    });

    try {
      if (widget.voicePath != null) {
        await _audioPlayer.setSource(DeviceFileSource(widget.voicePath!));
      } else if (widget.voiceUrl != null) {
        await _audioPlayer.setSource(UrlSource(widget.voiceUrl!));
      }
    } catch (e) {
      debugPrint('Ошибка инициализации аудио: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_cachedLocalPath != null) {
        await _audioPlayer.play(DeviceFileSource(_cachedLocalPath!));
      } else if (widget.onGetLocalAudio != null) {
        setState(() => _isLoadingAudio = true);
        try {
          final path = await widget.onGetLocalAudio!();
          if (path != null) {
            _cachedLocalPath = path;
            await _audioPlayer.play(DeviceFileSource(path));
          } else if (widget.voiceUrl != null) {
            await _audioPlayer.play(UrlSource(widget.voiceUrl!));
          }
        } finally {
          setState(() => _isLoadingAudio = false);
        }
      } else if (widget.voiceUrl != null) {
        await _audioPlayer.play(UrlSource(widget.voiceUrl!));
      }
    }
  }

  void _seekToPosition(double dx, double totalWidth) {
    if (totalWidth <= 0) return;
    final pct = (dx / totalWidth).clamp(0.0, 1.0);
    final displayDuration = _duration.inMilliseconds > 0 ? _duration : const Duration(seconds: 0);
    if (displayDuration.inMilliseconds > 0) {
      final newPosition = Duration(milliseconds: (displayDuration.inMilliseconds * pct).toInt());
      _audioPlayer.seek(newPosition);
      setState(() {
        _position = newPosition;
      });
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _togglePlaybackSpeed() async {
    double newSpeed;
    if (_playbackSpeed == 1.0) {
      newSpeed = 1.5;
    } else if (_playbackSpeed == 1.5) {
      newSpeed = 2.0;
    } else {
      newSpeed = 1.0;
    }
    await _audioPlayer.setPlaybackRate(newSpeed);
    setState(() {
      _playbackSpeed = newSpeed;
    });
  }

  Future<void> _handleTranscribe() async {
    debugPrint('[_VoiceMessagePlayerState] _handleTranscribe called. Current text: $_transcriptionText');
    if (_transcriptionText != null && _transcriptionText!.isNotEmpty) {
      setState(() {
        _showTranscription = !_showTranscription;
      });
      return;
    }

    if (widget.onTranscribe != null) {
      setState(() {
        _isTranscribing = true;
        _showTranscription = true;
      });
      
      try {
        final text = await widget.onTranscribe!();
        debugPrint('[_VoiceMessagePlayerState] Transcription text returned: $text');
        if (mounted) {
          setState(() {
            _isTranscribing = false;
            if (text != null && text.isNotEmpty) {
              _transcriptionText = text;
            } else {
              _showTranscription = false;
            }
          });
        }
      } catch (e) {
        debugPrint('[_VoiceMessagePlayerState] Transcription exception: $e');
        if (mounted) {
          setState(() {
            _isTranscribing = false;
            _transcriptionText = 'Ошибка распознавания: $e';
          });
        }
      }
    } else {
      debugPrint('[_VoiceMessagePlayerState] onTranscribe callback is null!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;
    final colorOnPrimary = widget.isOwn ? Colors.white : activeColor;
    final colorVariant = widget.isOwn ? Colors.white70 : theme.colorScheme.onSurfaceVariant;

    final displayDuration = _duration.inMilliseconds > 0 ? _duration : const Duration(seconds: 0);
    final progress = displayDuration.inMilliseconds > 0 
        ? _position.inMilliseconds / displayDuration.inMilliseconds 
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 250,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.transparentBackground
                ? Colors.transparent
                : (widget.isOwn ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHigh),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.isOwn ? Colors.white : activeColor,
                    shape: BoxShape.circle,
                  ),
                  child: _isLoadingAudio 
                    ? Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: CircularProgressIndicator(
                          color: widget.isOwn ? activeColor : Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: widget.isOwn ? activeColor : Colors.white,
                        size: 20,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onTapDown: (details) {
                            _seekToPosition(details.localPosition.dx, constraints.maxWidth);
                          },
                          onHorizontalDragUpdate: (details) {
                            _seekToPosition(details.localPosition.dx, constraints.maxWidth);
                          },
                          child: Container(
                            height: 24,
                            color: Colors.transparent, // expand gesture area
                            alignment: Alignment.center,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(_waveformHeights.length, (index) {
                                final isPlayed = (index / _waveformHeights.length) <= progress;
                                return Container(
                                  width: 3,
                                  height: _waveformHeights[index],
                                  decoration: BoxDecoration(
                                    color: isPlayed ? colorOnPrimary : colorVariant.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      }
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isPlaying ? _formatDuration(_position) : _formatDuration(displayDuration),
                          style: TextStyle(
                            color: colorVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            if (widget.onTranscribe != null)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _handleTranscribe,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _showTranscription 
                                        ? (widget.isOwn ? Colors.white.withValues(alpha: 0.25) : activeColor.withValues(alpha: 0.15))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.subtitles_rounded,
                                        size: 13,
                                        color: _showTranscription ? colorOnPrimary : colorVariant,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'А',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: _showTranscription ? colorOnPrimary : colorVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _togglePlaybackSpeed,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _playbackSpeed > 1.0 
                                      ? (widget.isOwn ? Colors.white.withValues(alpha: 0.25) : activeColor.withValues(alpha: 0.15))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_playbackSpeed == 1.0 ? "1" : _playbackSpeed == 1.5 ? "1.5" : "2"}x',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _playbackSpeed > 1.0 ? colorOnPrimary : colorVariant,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.onDownload != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: widget.onDownload,
                                child: Icon(
                                  Icons.download,
                                  size: 14,
                                  color: colorVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_showTranscription)
          Container(
            width: 250,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isOwn ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isTranscribing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: colorOnPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Расшифровка...',
                        style: TextStyle(
                          color: colorVariant,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ).animate().fadeIn().moveY(begin: -2, end: 0),
                    ],
                  )
                : Text(
                    _transcriptionText ?? 'Ошибка перевода',
                    style: TextStyle(
                      color: widget.isOwn ? Colors.white : theme.colorScheme.onSurface,
                      fontSize: 12.5,
                    ),
                  ).animate().fadeIn().moveY(begin: -2, end: 0),
          ),
      ],
    );
  }
}
