import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.asset(
      'assets/teknik_bakis_splash.mp4',
    );

    try {
      await _controller.initialize();
      _controller.setLooping(false);
      _controller.setVolume(1.0);

      // Video bitince ana ekrana geç
      _controller.addListener(_onVideoProgress);

      if (mounted) {
        setState(() {});
        _controller.play();
      }
    } catch (e) {
      // Video yüklenemezse fallback splash göster
      if (mounted) setState(() => _videoFailed = true);
      _navigateToHome();
    }
  }

  void _onVideoProgress() {
    if (!mounted) return;
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    if (dur.inMilliseconds > 0 && pos >= dur) {
      _controller.removeListener(_onVideoProgress);
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextScreen,
        transitionsBuilder: (context, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoProgress);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Video başarısız olduysa siyah ekran göster (geçiş zaten tetiklendi)
    if (_videoFailed) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
      : const SizedBox.shrink(),
    );
  }
}
