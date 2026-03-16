import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/pool_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/voice_expense_service.dart';
import '../../theme/app_colors.dart';
import 'add_expense_sheet.dart';

/// Bottom sheet for voice-based expense entry.
/// Flow: request mic permission → record → stop → send to backend → open AddSharedExpenseSheet pre-filled
Future<void> showVoiceRecorderSheet(BuildContext context, PoolModel pool) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    builder: (_) => _VoiceRecorderSheet(pool: pool),
  );
}

class _VoiceRecorderSheet extends StatefulWidget {
  final PoolModel pool;
  const _VoiceRecorderSheet({required this.pool});

  @override
  State<_VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<_VoiceRecorderSheet>
    with SingleTickerProviderStateMixin {
  // ─── State machine ───────────────────────────────────────────────────────
  _RecordPhase _phase = _RecordPhase.requestingPermission;
  String? _errorMessage;
  String? _transcriptPreview;

  // ─── Recording ────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  String? _audioPath;
  Timer? _timer;
  int _secondsElapsed = 0;

  // ─── Member names ─────────────────────────────────────────────────────────
  Map<String, String> _memberNames = {};
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.9, end: 1.1).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _init();
  }

  Future<void> _init() async {
    // Load member names (for passing to backend)
    for (final uid in widget.pool.members) {
      final user = await FirestoreService().getUser(uid);
      if (mounted) {
        _memberNames[uid] = (user?.displayName.isNotEmpty ?? false)
            ? user!.displayName
            : 'User';
      }
    }
    if (!mounted) return;
    await _requestAndRecord();
  }

  Future<void> _requestAndRecord() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;

    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() {
        _phase = _RecordPhase.error;
        _errorMessage = status.isPermanentlyDenied
            ? 'Microphone permission is permanently denied.\nPlease enable it in App Settings.'
            : 'Microphone permission is required to use Voice Expense.';
      });
      return;
    }

    await _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      // Check if recorder is already recording
      if (await _recorder.isRecording()) {
        print('⚠️ VoiceRecorder: Already recording, stopping first');
        await _recorder.stop();
      }
      
      // Get temp directory and create path
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/voice_expense_$timestamp.wav';
      
      print('🎙️ VoiceRecorder: Starting recording to: $path');
      print('🎙️ VoiceRecorder: Recorder initialized: ${_recorder}');

      // Check and request permission again to be sure
      final micStatus = await Permission.microphone.status;
      print('🎙️ VoiceRecorder: Microphone permission status: $micStatus');
      
      // Use WAV encoder for better emulator compatibility
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      
      // Verify recording started
      final isRecording = await _recorder.isRecording();
      print('🎙️ VoiceRecorder: Recording started: $isRecording');

      if (!isRecording) {
        throw Exception('Failed to start recording - recorder returned false');
      }

      _audioPath = path;
      _secondsElapsed = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted) return;
        
        // Check if still recording
        final stillRecording = await _recorder.isRecording();
        if (!stillRecording) {
          print('⚠️ VoiceRecorder: Recording stopped unexpectedly');
          _timer?.cancel();
          return;
        }
        
        setState(() => _secondsElapsed++);
        print('🎙️ VoiceRecorder: Recording for ${_secondsElapsed}s');
        
        // Auto-stop after 90 seconds
        if (_secondsElapsed >= 90) {
          print('🎙️ VoiceRecorder: Auto-stop after 90 seconds');
          _stopRecording();
        }
      });

      if (mounted) setState(() => _phase = _RecordPhase.recording);
      print('✅ VoiceRecorder: Recording phase active');
      
    } catch (e, stackTrace) {
      print('❌ VoiceRecorder: Error starting recording: $e');
      print('❌ VoiceRecorder: Stack trace: $stackTrace');
      if (mounted) setState(() {
        _phase = _RecordPhase.error;
        _errorMessage = 'Could not start microphone: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    print('🎙️ VoiceRecorder: Stop recording requested');
    _timer?.cancel();
    
    try {
      final wasRecording = await _recorder.isRecording();
      print('🎙️ VoiceRecorder: Was recording: $wasRecording');
      
      if (!wasRecording) {
        print('⚠️ VoiceRecorder: Not recording, nothing to stop');
        return;
      }

      setState(() => _phase = _RecordPhase.processing);
      
      // Stop the recorder
      print('🎙️ VoiceRecorder: Calling recorder.stop()');
      final recordedPath = await _recorder.stop();
      print('🎙️ VoiceRecorder: Recording stopped, file at: $recordedPath');
      
      if (recordedPath == null || recordedPath.isEmpty) {
        throw Exception('Recording file not found - recorder returned null or empty path');
      }
      
      // Check if file exists and has content
      final file = File(recordedPath);
      final exists = await file.exists();
      final fileSize = exists ? await file.length() : 0;
      
      print('🎙️ VoiceRecorder: File exists: $exists, Size: $fileSize bytes');
      print('🎙️ VoiceRecorder: Recording duration: $_secondsElapsed seconds');
      
      if (!exists || fileSize == 0) {
        throw Exception('Recording file is empty or does not exist. File exists: $exists, Size: $fileSize bytes');
      }
      
      // If recording was very short, it's likely empty
      if (_secondsElapsed < 1) {
        print('⚠️ VoiceRecorder: Recording was very short (${_secondsElapsed}s)');
      }
      
      await _sendToBackend(recordedPath);
      
    } catch (e, stackTrace) {
      print('❌ VoiceRecorder: Error stopping recording: $e');
      print('❌ VoiceRecorder: Stack trace: $stackTrace');
      if (mounted) setState(() {
        _phase = _RecordPhase.error;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _sendToBackend(String path) async {
    final members = widget.pool.members.map((uid) => {
      'uid': uid,
      'name': _memberNames[uid] ?? 'User',
    }).toList();

    try {
      final result = await VoiceExpenseService.analyze(
        audioPath: path,
        members: members,
      );

      if (!mounted) return;
      setState(() {
        _transcriptPreview = result.transcript;
        _phase = _RecordPhase.done;
      });

      // Small delay so user can see the transcript, then open form
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.pop(context); // close this sheet

      // Open add expense sheet pre-filled
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddSharedExpenseSheet(
          pool: widget.pool,
          prefilledAmount: result.amount,
          prefilledDescription: result.description,
          prefilledParticipants: result.participantUids.toSet(),
          prefilledPaidByUid: result.paidByUid,
        ),
      );
    } catch (e) {
      if (mounted) setState(() {
        _phase = _RecordPhase.error;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ─── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            _buildTitle(),
            const SizedBox(height: 32),
            _buildCenterWidget(),
            const SizedBox(height: 32),
            _buildBottomRow(context),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final titles = {
      _RecordPhase.requestingPermission: 'Voice Expense',
      _RecordPhase.recording: 'Listening...',
      _RecordPhase.processing: 'Analysing...',
      _RecordPhase.done: 'Got it!',
      _RecordPhase.error: 'Oops!',
    };
    return Text(
      titles[_phase] ?? 'Voice Expense',
      style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkBlue),
    );
  }

  Widget _buildCenterWidget() {
    switch (_phase) {
      case _RecordPhase.requestingPermission:
        return const CircularProgressIndicator(color: AppColors.primaryBlue);

      case _RecordPhase.recording:
        return Column(
          children: [
            ScaleTransition(
              scale: _pulse,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.errorRed.withAlpha(30),
                ),
                child: Center(
                  child: Container(
                    width: 68, height: 68,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.errorRed,
                    ),
                    child: const Icon(Icons.mic_rounded, color: Colors.white, size: 34),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _formatTime(_secondsElapsed),
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            const Text(
              'Speak your expense details\nthen tap Stop',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight, fontSize: 14),
            ),
          ],
        );

      case _RecordPhase.processing:
        return Column(
          children: [
            const SizedBox(
              width: 64, height: 64,
              child: CircularProgressIndicator(
                  color: AppColors.primaryBlue, strokeWidth: 3)),
            const SizedBox(height: 16),
            const Text(
              'Transcribing and parsing\nwith AI...',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight, fontSize: 14),
            ),
          ],
        );

      case _RecordPhase.done:
        return Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.successGreen.withAlpha(30),
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.successGreen, size: 40),
            ),
            if (_transcriptPreview != null) ...[
              const SizedBox(height: 16),
              Text(
                '"${_transcriptPreview!}"',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        );

      case _RecordPhase.error:
        return Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.errorRed.withAlpha(30),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.errorRed, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.errorRed, fontSize: 14),
            ),
          ],
        );
    }
  }

  Widget _buildBottomRow(BuildContext context) {
    if (_phase == _RecordPhase.recording) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _stopRecording,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Stop Recording',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.errorRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }

    if (_phase == _RecordPhase.error) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          if (_errorMessage?.contains('Settings') ?? false)
            Expanded(
              child: ElevatedButton(
                onPressed: openAppSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Open Settings'),
              ),
            )
          else
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() {
                  _phase = _RecordPhase.requestingPermission;
                  _errorMessage = null;
                  _requestAndRecord();
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ),
        ],
      );
    }

    if (_phase == _RecordPhase.processing || _phase == _RecordPhase.done) {
      return const SizedBox.shrink();
    }

    // requestingPermission
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

enum _RecordPhase { requestingPermission, recording, processing, done, error }
