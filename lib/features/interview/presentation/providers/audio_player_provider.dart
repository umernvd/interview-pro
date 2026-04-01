import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// Provider for managing audio playback state
class AudioPlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _currentFilePath;
  bool _isInitialized = false;
  String? _error;
  bool _isDisposed = false; // Track disposal state
  bool _isSeeking = false; // Track manual seeking to prevent stream conflicts

  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;

  // Getters
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  double get progress {
    if (_totalDuration.inMilliseconds == 0) return 0.0;
    return _currentPosition.inMilliseconds / _totalDuration.inMilliseconds;
  }

  /// Initialize audio player with file path
  Future<void> initialize(String filePath) async {
    if (_isDisposed) return;

    try {
      debugPrint('🎵 Initializing audio player with: $filePath');

      // CRITICAL: Reset all state and cleanup existing resources before reinitializing
      await _resetState();

      if (_isDisposed) return; // double check after async reset

      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        _error = 'Audio file not found';
        debugPrint('❌ Audio file does not exist: $filePath');
        notifyListeners();
        return;
      }

      _currentFilePath = filePath;
      _error = null;

      // Set audio source
      await _player.setSource(DeviceFileSource(filePath));

      // Read duration immediately after source is set (audioplayers may not fire
      // onDurationChanged until playback starts, leaving totalDuration at zero)
      final duration = await _player.getDuration();
      if (duration != null && duration > Duration.zero) {
        _totalDuration = duration;
        debugPrint('🎵 Audio duration (eager): ${duration.inSeconds}s');
      }

      // Listen to position changes
      _positionSubscription = _player.onPositionChanged.listen((position) {
        if (_isDisposed) return;
        if (_isSeeking) return; // Don't update position during manual seeking
        _currentPosition = position;
        notifyListeners();
      });

      // Listen to duration changes
      _durationSubscription = _player.onDurationChanged.listen((duration) {
        if (_isDisposed) return;
        _totalDuration = duration;
        debugPrint('🎵 Audio duration: ${duration.inSeconds}s');
        notifyListeners();
      });

      // Listen to player state changes
      _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
        if (_isDisposed) return;
        _isPlaying = state == PlayerState.playing;

        // Auto-reset when completed to allow replay
        if (state == PlayerState.completed) {
          _isPlaying = false;
          _currentPosition = Duration.zero; // Reset UI position
          // Seek to start to allow replay
          _player.seek(Duration.zero);
          debugPrint('🔄 Audio completed, reset to start for replay');
        }

        notifyListeners();
      });

      _isInitialized = true;
      debugPrint('✅ Audio player initialized successfully');
      notifyListeners();
    } catch (e) {
      if (!_isDisposed) {
        _error = 'Failed to load audio: $e';
        debugPrint('❌ Error initializing audio player: $e');
        notifyListeners();
      }
    }
  }

  /// Reset all state and cleanup resources (for reinitialization)
  Future<void> _resetState() async {
    debugPrint('🔄 Resetting audio player state');

    // Cleanup resources first
    await _cleanupResources();

    // Reset all state variables
    _isPlaying = false;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    _currentFilePath = null;
    _isInitialized = false;
    _error = null;
    // Do NOT reset _isDisposed here

    debugPrint('✅ Audio player state reset complete');
  }

  /// Cleanup resources without notifying listeners (for disposal)
  Future<void> _cleanupResources() async {
    // Stop playback if active
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('⚠️ Error stopping player during cleanup: $e');
    }

    // Cancel all existing stream subscriptions
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playerStateSubscription?.cancel();

    // Clear subscriptions
    _positionSubscription = null;
    _durationSubscription = null;
    _playerStateSubscription = null;
  }

  /// Play audio
  Future<void> play() async {
    if (_isDisposed) return;
    if (!_isInitialized || _currentFilePath == null) {
      debugPrint('⚠️ Cannot play: Audio not initialized');
      return;
    }

    try {
      // Use play() instead of resume() to work after completion
      await _player.play(DeviceFileSource(_currentFilePath!));
      debugPrint('▶️ Playing audio');
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
      if (!_isDisposed) {
        _error = 'Playback failed: $e';
        notifyListeners();
      }
    }
  }

  /// Pause audio
  Future<void> pause() async {
    if (_isDisposed) return;
    if (!_isInitialized) return;

    try {
      await _player.pause();
      debugPrint('⏸️ Paused audio');
    } catch (e) {
      debugPrint('❌ Error pausing audio: $e');
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    if (_isDisposed) return;
    if (!_isInitialized) return;

    try {
      // Clamp position to valid range
      final clampedPosition = Duration(
        milliseconds: position.inMilliseconds.clamp(
          0,
          _totalDuration.inMilliseconds,
        ),
      );

      // Update position immediately for responsive UI
      _currentPosition = clampedPosition;
      notifyListeners();

      // Perform actual seek
      await _player.seek(clampedPosition);
      debugPrint('⏩ Seeked to: ${clampedPosition.inSeconds}s');
    } catch (e) {
      debugPrint('❌ Error seeking: $e');
    }
  }

  /// Start manual seeking (called when user starts dragging slider)
  void startSeeking() {
    if (_isDisposed) return;
    _isSeeking = true;
    debugPrint('🎯 Started manual seeking');
  }

  /// End manual seeking (called when user releases slider)
  void endSeeking() {
    if (_isDisposed) return;
    _isSeeking = false;
    debugPrint('🎯 Ended manual seeking');
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isDisposed) return;
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Format duration as MM:SS
  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    if (_isDisposed) return; // Already disposed
    debugPrint('🗑️ Disposing audio player');

    // Mark as disposed FIRST to prevent stream listeners from calling notifyListeners
    _isDisposed = true;

    // Synchronously cleanup resources (no async needed for dispose)
    // Cancel subscriptions synchronously
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();

    // Stop and dispose player
    try {
      _player.stop();
      _player.dispose();
      debugPrint('✅ Audio player disposed completely');
    } catch (e) {
      debugPrint('⚠️ Error during disposal: $e');
    }

    super.dispose();
  }
}
