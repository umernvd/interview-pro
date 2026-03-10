import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../core/theme/app_theme_extensions.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/services/interview_session_manager.dart';
import '../../../../core/services/interview_media_upload_service.dart';
import '../../../../core/providers/auth_state_provider.dart';
import '../../../../shared/domain/entities/interview_question.dart';
import '../providers/interview_question_provider.dart';
import '../providers/voice_recording_provider.dart';
import '../widgets/audio_waveform_widget.dart';
import '../widgets/back_navigation_dialog.dart';

/// Interview question screen matching the provided HTML design
class InterviewQuestionPage extends StatefulWidget {
  final String selectedRole;
  final String selectedLevel;
  final String candidateName;
  final String? candidateEmail;
  final String? candidatePhone;
  final String? candidateCvId;
  final String? candidateCvUrl;
  final String? driveFolderId;

  const InterviewQuestionPage({
    super.key,
    required this.selectedRole,
    required this.selectedLevel,
    required this.candidateName,
    this.candidateEmail,
    this.candidatePhone,
    this.candidateCvId,
    this.candidateCvUrl,
    this.driveFolderId,
  });

  @override
  State<InterviewQuestionPage> createState() => _InterviewQuestionPageState();
}

class _InterviewQuestionPageState extends State<InterviewQuestionPage>
    with SingleTickerProviderStateMixin {
  bool? selectedAnswer; // null = no selection, true = Yes, false = No
  final TextEditingController notesController = TextEditingController();

  // Voice recording state
  // (Animation logic removed as per interview-wide session design)

  // Dynamic question data
  List<InterviewQuestion> _questions = [];
  int _currentQuestionIndex = 0;
  bool _isLoading = true;
  String? _error;

  // Interview session manager
  late final InterviewSessionManager _sessionManager;
  late final AuthStateProvider _authStateProvider;
  bool _sessionStarted = false;

  @override
  void initState() {
    super.initState();
    _sessionManager = sl<InterviewSessionManager>();
    _authStateProvider = sl<AuthStateProvider>();
    _loadQuestions();
  }

  /// Load questions based on selected role and experience level
  Future<void> _loadQuestions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final provider = context.read<InterviewQuestionProvider>();

      // Load questions filtered by role and difficulty level
      final questions = await provider.getRandomQuestions(
        count: 25, // Get 25 questions for the interview
        roleSpecific: widget.selectedRole,
        difficulty: _mapExperienceLevelToDifficulty(widget.selectedLevel),
      );

      if (mounted) {
        if (questions.isEmpty) {
          final generalQuestions = await provider.getRandomQuestions(
            count: 25,
            difficulty: _mapExperienceLevelToDifficulty(widget.selectedLevel),
          );

          if (mounted) {
            setState(() {
              _questions = generalQuestions;
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _questions = questions;
            _isLoading = false;
          });
        }
      }

      if (_questions.isEmpty) {
        if (mounted) {
          setState(() {
            _error = 'No questions found for the selected criteria';
          });
        }
        return;
      }

      // Start interview session after questions are loaded
      await _startInterviewSession();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load questions: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startInterviewSession() async {
    try {
      // Capture the started interview session
      final interview = await _sessionManager.startInterview(
        candidateName: widget.candidateName,
        candidateEmail: widget.candidateEmail,
        candidatePhone: widget.candidatePhone,
        candidateCvId: widget.candidateCvId,
        candidateCvUrl: widget.candidateCvUrl,
        driveFolderId: widget.driveFolderId, // 🟢 Passed from widget
        role: widget.selectedRole,
        level: widget.selectedLevel,
        questions: _questions,
      );

      if (mounted) {
        setState(() {
          _sessionStarted = true;
          _currentQuestionIndex = _sessionManager.currentQuestionIndex;
        });

        // 🟢 AUTO-START TRIGGER
        // Start recording immediately using the new interview ID
        final voiceProvider = context.read<VoiceRecordingProvider>();
        await voiceProvider.start(
          interviewId: interview.id,
          candidateName: widget.candidateName,
        );

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).clearSnackBars(); // Ensure clean slate but no new snackbar
        }
      }

      debugPrint('✅ Interview session started successfully');
    } catch (e) {
      debugPrint('❌ Error starting interview session: $e');
      // Continue without session tracking if it fails
      if (mounted) {
        setState(() {
          _sessionStarted = false;
        });
      }
    }
  }

  /// Map experience level to difficulty
  String _mapExperienceLevelToDifficulty(String level) {
    switch (level.toLowerCase()) {
      case 'intern':
        return 'beginner';
      case 'associate':
        return 'intermediate';
      case 'senior':
        return 'advanced';
      default:
        return 'intermediate';
    }
  }

  /// Get current question
  InterviewQuestion? get _currentQuestion {
    if (_sessionStarted && _sessionManager.hasActiveSession) {
      return _sessionManager.getCurrentQuestion();
    }

    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      return null;
    }
    return _questions[_currentQuestionIndex];
  }

  /// Get total questions count
  int get _totalQuestions {
    if (_sessionStarted && _sessionManager.hasActiveSession) {
      return _sessionManager.totalQuestions;
    }
    return _questions.length;
  }

  /// Get current question index
  int get _currentIndex {
    if (_sessionStarted && _sessionManager.hasActiveSession) {
      return _sessionManager.currentQuestionIndex;
    }
    return _currentQuestionIndex;
  }

  @override
  void dispose() {
    notesController.dispose();
    // Note: We don't clear the session here as it should persist
    // until the interview is completed or explicitly cancelled
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) async {
          if (didPop) return;

          // 1. Show confirmation dialog using shared widget
          final shouldDiscard = await BackNavigationDialog.show(context);

          if (shouldDiscard == true) {
            if (!context.mounted) return;

            // 2. Stop and delete recording
            // We use cancel() because we are discarding the session
            await context.read<VoiceRecordingProvider>().cancel();

            // 3. Clear session from memory
            // This ensures no state leaks into the next session
            _sessionManager.clearSession();

            debugPrint('🗑️ Interview session discarded and cleaned up');

            if (context.mounted) {
              context.pop();
            }
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: _isLoading
              ? _buildLoadingState()
              : _error != null
              ? _buildErrorState()
              : _questions.isEmpty
              ? _buildEmptyState()
              : _buildQuestionContent(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading interview questions...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Questions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.red[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadQuestions,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Questions Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'No questions found for ${widget.selectedRole} at ${widget.selectedLevel} level.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadQuestions,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reload Questions'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContent() {
    // VoiceRecordingProvider is used for auto-start, monitoring not needed for UI anymore
    // final provider = context.watch<VoiceRecordingProvider>();
    // Commented out to fix lint, but we use context.watch for the waveform below indirectly via the widget itself
    // or we can consume it here if needed.
    // Actually AudioWaveformWidget consumes the provider internally.
    // But to toggle the visibility of the waveform, we DO need to watch the provider here.

    // VoiceRecordingProvider is monitored by Consumer in sub-widgets
    // final provider = context.watch<VoiceRecordingProvider>();

    return Stack(
      children: [
        // Main content column
        Column(
          children: [
            // Status bar placeholder
            Container(
              height: MediaQuery.of(context).padding.top,
              decoration: const BoxDecoration(color: Colors.white),
            ),

            // Header
            _buildHeader(),

            // Progress bar
            _buildProgressBar(),

            // Main content
            Expanded(child: _buildMainContent()),

            // Bottom navigation
            _buildBottomNavigation(),
          ],
        ),

        // Floating Action Button REMOVED for Session-Based Automation
        // We now record the entire session automatically.
        // Manual control is disabled to prevent state conflicts.
        /*
        Positioned(
          left: 0,
          right: 0,
          bottom: 100, // Positioned above the bottom navigation
          child: IgnorePointer(
            ignoring: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Recording Time (if active) - positioned above FAB
                  if (isRecording)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ValueListenableBuilder<int>(
                        valueListenable: provider.recordingDurationNotifier,
                        builder: (context, seconds, child) {
                          return Text(
                            _formatDuration(seconds),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          );
                        },
                      ),
                    ),
                  // Voice Recorder FAB
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: FloatingActionButton(
                      onPressed: _toggleRecording,
                      backgroundColor: isRecording
                          ? AppColors.primary
                          : Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(
                          color: isRecording
                              ? Colors.transparent
                              : AppColors.primary,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isRecording ? Icons.stop : Icons.mic,
                        color: isRecording ? Colors.white : AppColors.primary,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        */
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: AppThemeExtensions.glassDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();

              // Use the same robust cleanup logic as PopScope
              final shouldDiscard = await BackNavigationDialog.show(context);

              if (shouldDiscard == true) {
                if (!mounted) return;

                await context.read<VoiceRecordingProvider>().cancel();
                _sessionManager.clearSession();

                debugPrint('🗑️ Interview session discarded via Close button');

                if (mounted) {
                  context.pop();
                }
              }
            },
            child: Container(
              width: 44, // Standard 44x44
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: const Icon(Icons.close, size: 24, color: Colors.black),
            ),
          ),

          // Question counter
          Text(
            'QUESTION ${_currentIndex + 1} OF $_totalQuestions',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentIndex + 1) / _totalQuestions;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Container(
        height: 6, // Slightly slimmer
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100], // Cleaner, more standard background
          borderRadius: BorderRadius.circular(3),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          width: MediaQuery.of(context).size.width * progress,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          24,
          0,
          24,
          20,
        ), // Significantly reduced from 100
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question number
            _buildQuestionNumber(),

            const SizedBox(height: 16),

            // Question text
            _buildQuestionText(),

            const SizedBox(height: 48),

            // Answer section
            _buildAnswerSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionNumber() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        '#${_currentIndex + 1}',
        key: ValueKey<int>(_currentIndex),
        style: const TextStyle(
          fontSize: 80,
          fontWeight: FontWeight.w900,
          color: AppColors.primary, // Set to 100% opacity using primary color
          height: 1.0,
          letterSpacing: -4,
        ),
      ),
    );
  }

  Widget _buildQuestionText() {
    final question = _currentQuestion;
    if (question == null) return const SizedBox.shrink();

    return Text(
      question.question,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.black,
        height: 1.2,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildAnswerSection() {
    return Column(
      children: [
        // Yes/No buttons
        _buildYesNoButtons(),

        const SizedBox(height: 32),

        // Notes Label
        const Row(
          children: [
            Icon(Icons.edit_note, size: 20, color: Color(0xFF64748B)),
            SizedBox(width: 8),
            Text(
              'Interview Notes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),

        // Notes input (ALWAYS VISIBLE)
        _buildNotesInput(),

        const SizedBox(height: 24),

        // 🎙️ Visual Feedback: Audio Waveform
        // Only visible when recording (which is always true during session, but good to have toggle)
        Consumer<VoiceRecordingProvider>(
          builder: (context, provider, child) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(sizeFactor: animation, child: child),
                );
              },
              child: provider.isRecording
                  ? const Column(
                      children: [
                        AudioWaveformWidget(
                          height: 48,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Recording Active',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            );
          },
        ),

        // Extra padding to avoid overlap with FAB/Bottom Nav
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildYesNoButtons() {
    return Row(
      children: [
        // No button
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedAnswer = false;
              });
              HapticFeedback.lightImpact();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 64,
              decoration:
                  AppThemeExtensions.clayDecoration(
                    color: selectedAnswer == false
                        ? Colors.grey[200]!
                        : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    isPressed: selectedAnswer == false,
                  ).copyWith(
                    border: Border.all(
                      color: selectedAnswer == false
                          ? Colors.grey[400]!
                          : Colors.grey[200]!,
                      width: 1.5,
                    ),
                  ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.close_rounded,
                    size: 24,
                    color: selectedAnswer == false
                        ? Colors.grey[700]
                        : Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.no,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: selectedAnswer == false
                          ? Colors.grey[800]
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 20),

        // Yes button
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedAnswer = true;
              });
              HapticFeedback.mediumImpact();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 64,
              decoration:
                  AppThemeExtensions.clayDecoration(
                    color: selectedAnswer == true
                        ? AppColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    isPressed: selectedAnswer == true,
                  ).copyWith(
                    border: Border.all(
                      color: selectedAnswer == true
                          ? AppColors.primary
                          : Colors.grey[200]!,
                      width: 1.5,
                    ),
                  ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_rounded,
                    size: 24,
                    color: selectedAnswer == true
                        ? Colors.white
                        : Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.yes,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: selectedAnswer == true
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesInput() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
      ),
      child: TextField(
        controller: notesController,
        maxLines: 4,
        minLines: 3,
        decoration: InputDecoration(
          hintText: 'Type your observations here...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
        ),
        style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          if (_currentIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _onPrevious,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Previous',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),

          if (_currentIndex > 0) const SizedBox(width: 16),

          // Next button
          Expanded(
            child: ElevatedButton(
              onPressed: _onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                _currentIndex == _totalQuestions - 1 ? 'Complete' : 'Next',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPrevious() {
    _sessionManager.previousQuestion();
    setState(() {
      _currentQuestionIndex = _sessionManager.currentQuestionIndex;
      // Load existing result if available
      final existingResult = _sessionManager.getResponseForQuestion(
        _currentIndex,
      );
      if (existingResult != null) {
        selectedAnswer = existingResult.isCorrect;
        notesController.text = existingResult.notes ?? '';
      } else {
        selectedAnswer = null;
        notesController.text = '';
      }
    });
  }

  void _onNext() async {
    if (selectedAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an answer (Yes/No)')),
      );
      return;
    }

    try {
      // Record current response
      await _sessionManager.recordResponse(
        isCorrect: selectedAnswer!,
        notes: notesController.text,
      );

      if (!mounted) return;

      if (_currentIndex < _totalQuestions - 1) {
        await _sessionManager.nextQuestion();
        if (!mounted) return;

        setState(() {
          _currentQuestionIndex = _sessionManager.currentQuestionIndex;
          // Check if next question already answered
          final existingResult = _sessionManager.getResponseForQuestion(
            _currentIndex,
          );
          if (existingResult != null) {
            selectedAnswer = existingResult.isCorrect;
            notesController.text = existingResult.notes ?? '';
          } else {
            selectedAnswer = null;
            notesController.text = '';
          }
        });
      } else {
        // Handle interview completion
        _completeInterview();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _completeInterview() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      // STOP Recording if it's active
      final recordingProvider = context.read<VoiceRecordingProvider>();

      // Stop and get path regardless of provider state (service now handles fallback)
      final recordingPath = await recordingProvider.stop();
      if (!mounted) return;

      final recordingDuration = recordingProvider.recordingDurationSeconds;

      // Complete interview in manager and capture the returned interview data
      final completedInterview = await _sessionManager.completeInterview(
        voiceRecordingPath: recordingPath,
        voiceRecordingDurationSeconds: recordingDuration,
      );
      if (!mounted) return;

      // Update interview with recording details if available
      debugPrint('📽️ Recording saved at: $recordingPath');
      debugPrint('✅ Interview completed: ${completedInterview.id}');

      if (mounted) {
        Navigator.pop(context); // Remove loading

        // Show non-dismissible upload overlay
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black.withOpacity(0.3),
            builder: (context) => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        // Upload media file to Next.js backend
        try {
          final mediaUploadService = sl<InterviewMediaUploadService>();

          final uploadResponse = await mediaUploadService.uploadInterviewMedia(
            mediaFilePath: recordingPath ?? '',
            candidateName: completedInterview.candidateName,
            roleName: completedInterview.roleName,
            companyId: _authStateProvider.companyId,
          );

          if (!mounted) return;

          // Close upload overlay
          Navigator.pop(context);

          debugPrint('✅ Media upload successful');
          debugPrint('🔗 Drive File URL: ${uploadResponse['driveFileUrl']}');

          // Get interviewId from backend response (backend is source of truth)
          final backendInterviewId = uploadResponse['interviewId'] as String?;
          if (backendInterviewId == null) {
            throw Exception('Backend did not return interviewId');
          }

          // Show success feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Interview Uploaded Successfully ✅'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }

          // Navigate to candidate evaluation page with backend-generated interviewId
          if (mounted) {
            context.go(
              '${AppRouter.candidateEvaluation}?candidateName=${Uri.encodeComponent(completedInterview.candidateName)}&candidateEmail=${Uri.encodeComponent(widget.candidateEmail ?? '')}&role=${Uri.encodeComponent(completedInterview.roleName)}&level=${Uri.encodeComponent(completedInterview.level.name)}&interviewId=${Uri.encodeComponent(backendInterviewId)}',
            );
          }
        } catch (uploadError) {
          if (!mounted) return;

          // Close upload overlay
          Navigator.pop(context);

          debugPrint('❌ Media upload failed: $uploadError');

          // CRITICAL: DO NOT navigate on upload failure
          // Show error and allow user to retry
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $uploadError. Please try again.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );

          // Stay on current screen - user can retry "Complete Interview"
          // The media file is still available for retry
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Remove loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to complete: $e')));
      }
    }
  }
}
