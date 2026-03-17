import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/document_header_widget.dart';
import '../widgets/candidate_info_box_widget.dart';
import '../widgets/technical_questions_widget.dart';
import '../widgets/soft_skills_grid_widget.dart';
import '../widgets/recommendation_box_widget.dart';
import '../providers/report_data_provider.dart';
import '../../core/services/report_pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/download_success_dialog.dart';

/// Report preview screen showing PDF-style interview evaluation report
class ReportPreviewPage extends StatefulWidget {
  final String? interviewId; // Interview ID for data loading

  const ReportPreviewPage({super.key, this.interviewId});

  @override
  State<ReportPreviewPage> createState() => _ReportPreviewPageState();
}

class _ReportPreviewPageState extends State<ReportPreviewPage> {
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
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6F6),
        body: Consumer<ReportDataProvider>(
          builder: (context, provider, child) {
            // Show loading state
            if (provider.isLoading) {
              return _buildLoadingState();
            }

            // Show error state
            if (provider.error != null) {
              return _buildErrorState(provider.error!);
            }

            // Show PDF document with real data
            return _buildPDFDocument(provider.reportData);
          },
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
            'Loading interview data...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
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
            'Error Loading Report',
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildPDFDocument(ReportData? reportData) {
    return Stack(
      children: [
        Column(
          children: [
            // Status bar placeholder
            Container(
              height: MediaQuery.of(context).padding.top,
              decoration: const BoxDecoration(color: Color(0xFFF8F6F6)),
            ),

            // Header
            _buildHeader(context),

            // Main content
            Expanded(child: _buildMainContent(reportData)),
          ],
        ),

        // Floating action bar
        _buildFloatingActionBar(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F6F6),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
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
              'Report Preview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                letterSpacing: -0.015,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Share button
          GestureDetector(
            onTap: () => _onShare(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.share,
                size: 24,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ReportData? reportData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 595),
          child: _buildPDFContent(reportData),
        ),
      ),
    );
  }

  Widget _buildPDFContent(ReportData? reportData) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document header
              const DocumentHeaderWidget(),

              const SizedBox(height: 24),

              // Candidate info box
              CandidateInfoBoxWidget(
                candidateName: reportData?.interview.candidateName ?? 'N/A',
                role: reportData?.roleName ?? 'N/A',
                level: reportData?.interview.level.title ?? 'N/A',
                date: _formatDate(
                  reportData?.interview.startTime ?? DateTime.now(),
                ),
              ),

              const SizedBox(height: 24),

              // Overall score section
              _buildOverallScoreSection(reportData),

              const SizedBox(height: 24),

              // Technical questions
              TechnicalQuestionsWidget(
                questions: _generateRealTechnicalQuestions(reportData),
              ),

              const SizedBox(height: 24),

              // Soft skills
              SoftSkillsGridWidget(
                communicationSkills: reportData?.communicationSkills ?? 0,
                problemSolvingApproach: reportData?.problemSolvingApproach ?? 0,
                culturalFit: reportData?.culturalFit ?? 0,
                overallImpression: reportData?.overallImpression ?? 0,
              ),

              const SizedBox(height: 24),

              // Recommendation box
              RecommendationBoxWidget(
                overallScore: reportData?.overallScore ?? 0.0,
                recommendation: reportData?.recommendation,
              ),

              const SizedBox(height: 24),

              // Comments section (only if not empty)
              if (reportData?.additionalComments != null &&
                  reportData!.additionalComments.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildCommentsSection(reportData),
              ],

              const SizedBox(height: 32),

              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverallScoreSection(ReportData? reportData) {
    final percentage = (reportData?.overallScore ?? 0.0).toInt();

    return Center(
      child: Column(
        children: [
          Text(
            '$percentage%',
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              height: 1.0,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'OVERALL SCORE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(ReportData? reportData) {
    final comments = reportData?.additionalComments ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INTERVIEWER COMMENTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            '"$comments"',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(color: Color(0xFFE2E8F0)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Generated by InterviewPro',
              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
            Text(
              _formatDate(DateTime.now()),
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ],
    );
  }

  // Removed _buildWatermark as requested

  Widget _buildFloatingActionBar(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[100]!, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          children: [
            // Download PDF button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => _onDownloadPDF(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  shadowColor: AppColors.primary.withValues(alpha: 0.2),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Download PDF',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            // Share report button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: _onShare,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: BorderSide(color: Colors.grey[200]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.ios_share, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Share Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  List<TechnicalQuestion> _generateRealTechnicalQuestions(
    ReportData? reportData,
  ) {
    if (reportData == null || reportData.questionBreakdown.isEmpty) {
      return [];
    }

    final questions = <TechnicalQuestion>[];

    for (final breakdown in reportData.questionBreakdown) {
      for (final response in breakdown.responses) {
        questions.add(
          TechnicalQuestion(
            response.questionText,
            response.notes ?? 'No notes provided',
            response.isCorrect,
            questionId: response.questionId,
          ),
        );
      }
    }

    return questions.take(3).toList(); // Show only 3 questions top
  }

  void _onDownloadPDF() async {
    final reportData = context.read<ReportDataProvider>().reportData;
    if (reportData == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final path = await ReportPdfService.generatePdfFile(
        reportData,
        isPreview: false,
      );

      if (mounted) {
        Navigator.pop(context); // Remove loading

        final fileName =
            'Interview_Report_${reportData.interview.candidateName.replaceAll(' ', '_')}.pdf';

        DownloadSuccessDialog.show(context, fileName: fileName, filePath: path);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Remove loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving PDF: $e')));
      }
    }
  }

  void _onShare() async {
    final reportData = context.read<ReportDataProvider>().reportData;
    if (reportData == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final path = await ReportPdfService.generatePdfFile(reportData);

      if (mounted) {
        Navigator.pop(context); // Remove loading

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
        Navigator.pop(context); // Remove loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }
}

// Data classes
class TechnicalQuestion {
  final String question;
  final String feedback;
  final bool isCorrect;
  final String questionId;

  TechnicalQuestion(
    this.question,
    this.feedback,
    this.isCorrect, {
    this.questionId = '',
  });
}
