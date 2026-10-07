// lib/widgets/chat_video_bubble.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ChatVideoBubble extends StatefulWidget {
  final String? videoUrl;
  final String? localPath;
  final String fileName;
  final bool isOwn;
  final VoidCallback onDownload;

  const ChatVideoBubble({
    super.key,
    this.videoUrl,
    this.localPath,
    required this.fileName,
    required this.isOwn,
    required this.onDownload,
  });

  @override
  State<ChatVideoBubble> createState() => _ChatVideoBubbleState();
}

class _ChatVideoBubbleState extends State<ChatVideoBubble> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      if (widget.localPath != null && widget.localPath!.isNotEmpty) {
        _controller = VideoPlayerController.file(File(widget.localPath!));
      } else if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
        final fullUrl = widget.videoUrl!.startsWith('http')
            ? widget.videoUrl!
            : 'https://helper.savt.by${widget.videoUrl!}';
        _controller = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
      }

      if (_controller != null) {
        await _controller!.initialize();
        _controller!.addListener(_videoListener);
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _videoListener() {
    if (_controller == null || !mounted) return;
    final playing = _controller!.value.isPlaying;
    if (playing != _isPlaying) {
      setState(() {
        _isPlaying = playing;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
        _showControls = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_hasError) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 40),
              const SizedBox(height: 8),
              Text(
                'Ошибка воспроизведения видео',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              TextButton.icon(
                onPressed: widget.onDownload,
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text('Скачать видео', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );
    }

    final value = _controller!.value;
    final durationText = _formatDuration(value.duration);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Видеоплеер
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showControls = !_showControls;
                  });
                },
                child: VideoPlayer(_controller!),
              ),

              // Затемнение при показе панели управления
              if (_showControls || !_isPlaying)
                Positioned.fill(
                  child: Container(
                    color: Colors.black38,
                  ),
                ),

              // Кнопка Play в центре
              if (_showControls || !_isPlaying)
                Center(
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),

              // Нижняя панель управления
              if (_showControls || !_isPlaying)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Время воспроизведения / Длительность
                        ValueListenableBuilder(
                          valueListenable: _controller!,
                          builder: (context, VideoPlayerValue value, child) {
                            return Text(
                              '${_formatDuration(value.position)} / $durationText',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            );
                          },
                        ),
                        // Кнопки действий
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download_for_offline, color: Colors.white, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: widget.onDownload,
                              tooltip: 'Сохранить в галерею',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // Ползунок воспроизведения в самом низу
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 4,
                  child: VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: theme.colorScheme.primary,
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
