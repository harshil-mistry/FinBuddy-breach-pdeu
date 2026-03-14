import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../main.dart';
import '../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _playVideo();
  }

  Future<void> _playVideo() async {
    _controller = VideoPlayerController.asset('assets/animation.mp4');
    
    try {
      await _controller.initialize();
      setState(() {
        _isVideoInitialized = true;
      });
      
      _controller.play();

      // Listen for when the video reaches the end
      _controller.addListener(_onVideoComplete);
    } catch (e) {
      // Fallback if video fails to load
      debugPrint("Error loading splash video: $e");
      _navigateToHome();
    }
  }

  void _onVideoComplete() {
    if (_controller.value.position >= _controller.value.duration && _isVideoInitialized) {
      _controller.removeListener(_onVideoComplete);
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthenticationWrapper()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isVideoInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width:  _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : const ColoredBox(
              color: Colors.white,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              ),
            ),
    );
  }
}
