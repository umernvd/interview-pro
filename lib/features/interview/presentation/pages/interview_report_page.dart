import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../core/theme/app_theme_extensions.dart';
import '../providers/report_data_provider.dart';
import '../widgets/circular_progress_widget.dart';
import '../widgets/quick_stats_widget.dart';
import '../widgets/candidate_info_card.dart';
import '../widgets/audio_player_widget.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../core/services/report_pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/download_success_dialog.dart';
import '../../../../shared/presentation/widgets/loading_overlay.dart';

/// Interview report screen showing detailed evaluation results
class InterviewReportPage extends StatefulWidget {
  final String candidateName;
  final String role;
  final String level;
  final double overallScore;
  final int communicationSkills;
  final int problemSolvingApproach;
  final int culturalFit;
  final int overallImpression;
  final String additionalComments;
  final String? interviewId; // Add interview ID for data loading

  const InterviewReportPage({
    super.key,
    required this.candidateName,
    required this.role,
    required this.level,
    required this.overallScore,
    required this.communicationSkills,
    required this.problemSolvingApproach,
    required this.culturalFit,
    required this.overallImpression,
    required this.additionalComments,
    this.interviewId,
  });

  @override
  State<InterviewReportPage> createState() => _InterviewReportPageState();
}

class _InterviewReportPageState extends State<InterviewReportPage> {
  @override
  void initState() {
    super.initState();
    // Load interview data if ID is provided
    if (widget.interviewId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ReportDataProvider>().loadInterviewData(
          widget.interviewId!,
        );
      });
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
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: Stack(
          children: [
            Column(
              children: [
                // Status bar placeholder
                Container(
                  height: MediaQuery.of(context).padding.top,
                  decoration: const BoxDecoration(color: Colors.white),
                ),

                // Header
                _buildHeader(context),

                // Main content
                Expanded(child: _buildMainContent()),
              ],
            ),

            // Bottom actions
            _buildBottomActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: AppThemeExtensions.glassDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.read<DashboardProvider>().refresh();
              context.pop();
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

          // Title (centered)
          const Expanded(
            child: Text(
              AppStrings.interviewReport,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: -0.8,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Download only
          _buildHeaderAction(
            icon: Icons.download_rounded,
            onTap: () {
              HapticFeedback.mediumImpact();
              _onDownloadReport();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Icon(icon, size: 20, color: Colors.black),
      ),
    );
  }

  Widget _buildMainContent() {
    return Consumer<ReportDataProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (provider.error != null) {
          return _buildErrorState(provider.error!);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 140),
          child: Column(
            children: [
              // Candidate profile section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                  ),
                ),
                child: _buildCandidateProfile(provider.reportData),
              ),

              // Score hero section
              _buildScoreHero(provider.reportData),

              // Audio player (if recording exists)
              if (provider.reportData?.voiceRecordingPath != null) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AudioPlayerWidget(
                    key: ValueKey(
                      provider.reportData!.voiceRecordingPath!,
                    ), // ⚡ FIX: Force fresh widget on new path
                    audioPath: provider.reportData!.voiceRecordingPath!,
                    durationSeconds:
                        provider.reportData!.voiceRecordingDurationSeconds,
                    transcript: provider.reportData!.interview.transcript,
                    candidateName: widget.candidateName,
                    role: widget.role,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Quick stats
              _buildQuickStats(provider.reportData),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            AppStrings.errorLoading,
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
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.red[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateProfile(ReportData? reportData) {
    return Column(
      children: [
        // Reuse CandidateInfoCard for consistency
        Center(
          child: CandidateInfoCard(
            candidateName: widget.candidateName,
            role: widget.role,
            level: widget.level,
            interviewDate: reportData?.interview.startTime ?? DateTime.now(),
            cvUrl: reportData?.interview.candidateCvUrl,
          ),
        ),

        const SizedBox(height: 16),

        // Separate recommendation badge
        _buildRecommendationBadge(reportData),
      ],
    );
  }

  Widget _buildRecommendationBadge(ReportData? reportData) {
    final score = reportData?.overallScore ?? widget.overallScore;
    final isRecommended = score >= 70.0;
    final color = isRecommended
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    final icon = isRecommended ? Icons.verified_rounded : Icons.cancel_rounded;
    final text = isRecommended ? 'Recommended for Hire' : 'Not Recommended';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreHero(ReportData? reportData) {
    final score = reportData?.overallScore ?? widget.overallScore;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: CircularProgressWidget(
        score: score,
        size: 192,
        label: AppStrings.overallScore,
      ),
    );
  }

  Widget _buildQuickStats(ReportData? reportData) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.quickStats,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          QuickStatsWidget(
            totalQuestions: reportData?.totalQuestions ?? 25,
            correctAnswers:
                reportData?.correctAnswers ?? _calculateCorrectAnswers(),
            answeredQuestions: reportData?.answeredQuestions,
            completionPercentage: reportData?.completionPercentage,
            duration: reportData?.duration,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          children: [
            // Preview PDF button
            GestureDetector(
              onTap: () {
                HapticFeedback.heavyImpact();
                _onDownloadPDF(context);
              },
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: AppThemeExtensions.primaryGradientDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Text(
                      AppStrings.previewPdf,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            // Share report button
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _onShareReport();
              },
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.ios_share_rounded,
                      size: 22,
                      color: Colors.black87,
                    ),
                    SizedBox(width: 12),
                    Text(
                      AppStrings.shareReport,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateCorrectAnswers() {
    final totalRating =
        widget.communicationSkills +
        widget.problemSolvingApproach +
        widget.culturalFit +
        widget.overallImpression;
    return ((totalRating / 20.0) * 25).round();
  }

  void _onDownloadPDF(BuildContext context) {
    // Navigate to report preview with only interview ID - all data loaded from provider
    context.push(
      '${AppRouter.reportPreview}?interviewId=${widget.interviewId}',
    );
  }

  void _onShareReport() async {
    final reportData = context.read<ReportDataProvider>().reportData;
    if (reportData == null) return;

    // Show loading indicator
    LoadingOverlay.show(context, message: 'Generating PDF...');

    try {
      final path = await ReportPdfService.generatePdfFile(reportData);

      if (mounted) {
        LoadingOverlay.hide(context); // Remove loading

        // Use native share sheet
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'Interview Report - ${reportData.interview.candidateName}',
          text:
              'Evaluation report for candidate: ${reportData.interview.candidateName}',
        );
      }
    } catch (e) {
      if (mounted) {
        LoadingOverlay.hide(context); // Remove loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.errorGeneratingPdf}: $e')),
        );
      }
    }
  }

  void _onDownloadReport() async {
    final reportData = context.read<ReportDataProvider>().reportData;
    if (reportData == null) return;

    // Show loading indicator
    LoadingOverlay.show(context, message: 'Saving PDF...');

    try {
      final path = await ReportPdfService.generatePdfFile(
        reportData,
        isPreview: false,
      );

      if (mounted) {
        LoadingOverlay.hide(context); // Remove loading

        final fileName =
            'Interview_Report_${reportData.interview.candidateName.replaceAll(' ', '_')}.pdf';

        DownloadSuccessDialog.show(context, fileName: fileName, filePath: path);
      }
    } catch (e) {
      if (mounted) {
        LoadingOverlay.hide(context); // Remove loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.errorSavingPdf}: $e')),
        );
      }
    }
  }
}
