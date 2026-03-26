import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../shared/domain/entities/interview.dart';
import '../../../../shared/domain/repositories/interview_repository.dart';
import '../providers/evaluation_provider.dart';
import '../widgets/candidate_info_card.dart';
import '../widgets/evaluation_form_widget.dart';
import '../widgets/back_navigation_dialog.dart';
import '../../../../shared/presentation/widgets/premium_card.dart';
import '../../../../shared/presentation/widgets/metric_card.dart';
import '../../../../shared/presentation/widgets/loading_overlay.dart';
import '../../../../core/services/transcription_service.dart';

/// Candidate evaluation screen for assessing soft skills and generating reports
class CandidateEvaluationPage extends StatefulWidget {
  final String candidateName;
  final String? candidateEmail;
  final String role;
  final String level;
  final String interviewId;

  const CandidateEvaluationPage({
    super.key,
    required this.candidateName,
    this.candidateEmail,
    required this.role,
    required this.level,
    required this.interviewId,
  });

  @override
  State<CandidateEvaluationPage> createState() =>
      _CandidateEvaluationPageState();
}

class _CandidateEvaluationPageState extends State<CandidateEvaluationPage> {
  Interview? _completedInterview;
  bool _loadingInterview = true;

  /// Transcript cache for background processing
  String? _transcriptCache;
  bool _isBackgroundTranscribing = false;
  Future<String>? _transcriptionFuture;
  StreamSubscription? _sttSubscription;

  @override
  void initState() {
    super.initState();
    _loadInterviewData().then((_) {
      _startBackgroundTranscription();
    });

    // Listen for transcription completion in background
    _sttSubscription = sl<TranscriptionService>().statusStream.listen((
      results,
    ) {
      if (results.containsKey(widget.interviewId)) {
        if (mounted) {
          setState(() {
            _transcriptCache = results[widget.interviewId];
            _isBackgroundTranscribing = false;
          });
        }
        debugPrint('🎯 STT Sync complete for: ${widget.interviewId}');
      }
    });

    // Load existing evaluation if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EvaluationProvider>().loadEvaluation(widget.interviewId);
    });
  }

  /// Start transcribing in background as soon as we have the data
  Future<void> _startBackgroundTranscription() async {
    final path = _completedInterview?.voiceRecordingPath;
    final existingTranscript = _completedInterview?.transcript;

    // Phase 3: If we already have a transcript in the DB, use it and stop
    if (existingTranscript != null && existingTranscript.isNotEmpty) {
      if (mounted) {
        setState(() {
          _transcriptCache = existingTranscript;
          _isBackgroundTranscribing = false;
        });
      }
      debugPrint('📜 Using existing transcript from database');
      return;
    }

    if (path == null || path.isEmpty || _transcriptCache != null) return;

    if (mounted) setState(() => _isBackgroundTranscribing = true);
    try {
      final service = sl<TranscriptionService>();

      // Real-World Optimization: Check if task already started in previous screen
      _transcriptionFuture = service.getActiveTask(widget.interviewId);

      if (_transcriptionFuture == null) {
        debugPrint('🔄 No active task found, starting fresh background STT...');
        _transcriptionFuture = service.transcribeFile(
          path,
          role: widget.role,
          level: widget.level,
        );
      } else {
        debugPrint(
          '🤝 Picking up existing STT task for: ${widget.interviewId}',
        );
      }

      final result = await _transcriptionFuture;
      if (mounted) {
        setState(() {
          _transcriptCache = result;
          _isBackgroundTranscribing = false;
        });
      }
      debugPrint(
        '⚡ Background STT Complete: ${_transcriptCache?.substring(0, min(20, _transcriptCache!.length))}...',
      );
    } catch (e) {
      debugPrint('⚠️ Background STT failed: $e');
      if (mounted) setState(() => _isBackgroundTranscribing = false);
    }
  }

  /// Load interview data from repository
  Future<void> _loadInterviewData() async {
    try {
      final interviewRepository = sl<InterviewRepository>();
      final interview = await interviewRepository.getInterviewById(
        widget.interviewId,
      );

      if (mounted) {
        setState(() {
          _completedInterview = interview;
          _loadingInterview = false;
          // Phase 3: If the interview already has a transcript (saved in background), cache it
          if (interview?.transcript != null &&
              interview!.transcript!.isNotEmpty) {
            _transcriptCache = interview.transcript;
            _isBackgroundTranscribing = false;
          }
        });
      }

      if (interview != null) {
        debugPrint('✅ Loaded interview data: ${interview.id}');
      }
    } catch (e) {
      debugPrint('❌ Error loading interview data: $e');
      if (mounted) {
        setState(() {
          _loadingInterview = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Black icons for light theme
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) async {
          if (didPop) return;

          final provider = context.read<EvaluationProvider>();
          if (provider.isSaved) {
            if (context.mounted) {
              context.go(AppRouter.dashboard);
            }
            return;
          }

          final shouldPop = await BackNavigationDialog.show(context);
          if (shouldPop == true) {
            if (!context.mounted) return;

            // Show loading indicator
            LoadingOverlay.show(context, message: AppStrings.deleting);

            // Delete the interview from database
            try {
              final interviewRepository = sl<InterviewRepository>();
              await interviewRepository.deleteInterview(widget.interviewId);
              debugPrint('✅ Interview ${widget.interviewId} deleted');
            } catch (e) {
              debugPrint('❌ Error deleting interview: $e');
            }

            // Dismiss loading and navigate
            if (context.mounted) {
              context.pop(); // Dismiss loading
              context.go(AppRouter.dashboard);
            }
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: Column(
            children: [
              // Status bar placeholder
              Container(
                height: MediaQuery.of(context).padding.top,
                decoration: const BoxDecoration(color: Colors.white),
              ),

              // Header
              _buildHeader(),

              // Main content
              Expanded(child: _buildMainContent()),

              // Bottom button
              _buildBottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () async {
              final provider = context.read<EvaluationProvider>();
              if (provider.isSaved) {
                context.go(AppRouter.dashboard);
                return;
              }

              final shouldPop = await BackNavigationDialog.show(context);
              if (shouldPop == true) {
                if (!mounted) return;

                // Show loading indicator
                LoadingOverlay.show(context, message: AppStrings.deleting);

                // Delete the interview from database
                try {
                  final interviewRepository = sl<InterviewRepository>();
                  await interviewRepository.deleteInterview(widget.interviewId);
                  debugPrint('✅ Interview ${widget.interviewId} deleted');
                } catch (e) {
                  debugPrint('❌ Error deleting interview: $e');
                }

                // Dismiss loading and navigate
                if (mounted) {
                  LoadingOverlay.hide(context); // Dismiss loading
                  context.go(AppRouter.dashboard);
                }
              }
            },
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 24,
                color: AppColors.primary,
              ),
            ),
          ),

          // Title and subtitle (centered)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  AppStrings.candidateEvaluation,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Soft Skills Assessment',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Invisible spacer to balance the back button
          SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // CRITICAL FIX: Reset form state when leaving the screen
    context.read<EvaluationProvider>().resetForm();
    _sttSubscription?.cancel();
    super.dispose();
  }

  Widget _buildMainContent() {
    return Consumer<EvaluationProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading || _loadingInterview) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Candidate info card - centered
              Center(
                child: CandidateInfoCard(
                  candidateName:
                      _completedInterview?.candidateName ??
                      widget.candidateName,
                  candidateEmail: widget.candidateEmail,
                  role: _completedInterview?.roleName ?? widget.role,
                  level: _completedInterview?.level.title ?? widget.level,
                  interviewDate:
                      _completedInterview?.startTime ?? DateTime.now(),
                  cvUrl: _completedInterview?.candidateCvUrl,
                ),
              ),

              const SizedBox(height: 24),

              // Interview performance summary (if available)
              if (_completedInterview != null) ...[
                _buildInterviewPerformanceSummary(),
                const SizedBox(height: 24),
              ],

              // Evaluation form
              EvaluationFormWidget(
                technicalScore: _completedInterview?.technicalScore,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build interview performance summary widget
  Widget _buildInterviewPerformanceSummary() {
    final interview = _completedInterview!;
    final stats = interview.getPerformanceStats();

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Interview Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Performance metrics
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: AppStrings.technicalScore,
                  value: AppFormatters.formatScore(interview.technicalScore),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  title: AppStrings.questionsAnswered,
                  value:
                      '${stats['answeredQuestions']}/${stats['totalQuestions']}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: AppStrings.correctAnswers,
                  value: '${stats['correctAnswers']}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  title: AppStrings.completion,
                  value: AppFormatters.formatScore(
                    stats['completionPercentage'],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Consumer<EvaluationProvider>(
      builder: (context, provider, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[100]!, width: 1)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: provider.isFormValid && !provider.isSaving
                  ? () => _onGenerateReport(provider)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: provider.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assessment, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.generateReport,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onGenerateReport(EvaluationProvider provider) async {
    final recordingPath = _completedInterview?.voiceRecordingPath;
    String finalTranscript = _transcriptCache ?? '';

    // Treat error messages as empty transcripts for persistence logic
    if (finalTranscript.startsWith(TranscriptionService.errorPrefix)) {
      finalTranscript = '';
    }

    // If still transcribing in background, wait for it
    if (finalTranscript.isEmpty &&
        _isBackgroundTranscribing &&
        _transcriptionFuture != null) {
      LoadingOverlay.show(context, message: 'Finishing AI transcription...');
      try {
        finalTranscript = await _transcriptionFuture!;
      } catch (e) {
        debugPrint('⚠️ Transcription wait failed: $e');
      } finally {
        if (mounted) LoadingOverlay.hide(context);
      }
    }
    // Final fallback: If we still don't have it, check the repository one last time
    // (in case background auto-persistence finished while we were on the page)
    else if (finalTranscript.isEmpty) {
      try {
        final repo = sl<InterviewRepository>();
        final interview = await repo.getInterviewById(widget.interviewId);
        if (!mounted) return;
        if (interview?.transcript != null &&
            interview!.transcript!.isNotEmpty) {
          finalTranscript = interview.transcript!;
        }
        // Only if REALLY missing, trigger a final manual attempt
        else if (recordingPath != null && recordingPath.isNotEmpty) {
          LoadingOverlay.show(
            context,
            message: 'Transcribing interview with Gemini AI...',
          );
          final transcriptionService = sl<TranscriptionService>();
          finalTranscript = await transcriptionService.transcribeFile(
            recordingPath,
            role: widget.role,
            level: widget.level,
          );
          if (mounted) LoadingOverlay.hide(context);
        }
      } catch (e) {
        debugPrint('⚠️ Final transcription recovery failed: $e');
        if (mounted) LoadingOverlay.hide(context);
      }
    }

    // 3. Save evaluation with transcript
    final success = await provider.saveEvaluation(
      interviewId: widget.interviewId,
      candidateName: widget.candidateName,
      role: widget.role,
      level: widget.level,
      transcript: finalTranscript,
    );

    if (!mounted) return;

    if (success) {
      // Use technical-only score as overall score per user requirement
      double overallScore =
          _completedInterview?.technicalScore ?? provider.calculatedScore;

      // Show report with real data
      _showReportDialog(provider, overallScore);
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save evaluation. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showReportDialog(EvaluationProvider provider, double overallScore) {
    // Navigate to interview report page with actual calculated data and interview ID
    final interviewId = _completedInterview?.id ?? widget.interviewId;
    final finalInterviewId = interviewId.isNotEmpty ? interviewId : '';
    context.push(
      '${AppRouter.interviewReport}?candidateName=${widget.candidateName}&role=${widget.role}&level=${widget.level}&overallScore=${overallScore.toStringAsFixed(1)}&communicationSkills=${provider.communicationSkills}&problemSolvingApproach=${provider.problemSolvingApproach}&culturalFit=${provider.culturalFit}&overallImpression=${provider.overallImpression}&additionalComments=${Uri.encodeComponent(provider.additionalComments)}&interviewId=$finalInterviewId',
    );
  }
}
