import 'package:flutter/foundation.dart';
import '../../../../shared/domain/entities/entities.dart';
import '../../../../shared/domain/repositories/interview_repository.dart';

/// Provider for aggregating and managing report data
class ReportDataProvider extends ChangeNotifier {
  final InterviewRepository _interviewRepository;

  ReportDataProvider(this._interviewRepository);

  bool _isLoading = false;
  Interview? _currentInterview;
  ReportData? _reportData;
  String? _error;

  // Getters
  bool get isLoading => _isLoading;
  Interview? get currentInterview => _currentInterview;
  ReportData? get reportData => _reportData;
  String? get error => _error;

  /// Load interview data and generate report data
  Future<void> loadInterviewData(String interviewId) async {
    debugPrint('🔄 Starting to load interview data for ID: $interviewId');

    _isLoading = true;
    _error = null;
    _currentInterview = null; // ⚡ FIX: Clear stale interview data
    _reportData = null; // ⚡ FIX: Clear stale report data
    notifyListeners();

    try {
      debugPrint('📞 Calling repository.getInterviewById($interviewId)');

      // Load interview from repository
      _currentInterview = await _interviewRepository.getInterviewById(
        interviewId,
      );

      debugPrint(
        '📋 Repository returned: ${_currentInterview != null ? 'Interview found' : 'null'}',
      );

      if (_currentInterview == null) {
        _error = 'Interview not found';
        debugPrint('❌ Interview not found in repository for ID: $interviewId');
        return;
      }

      debugPrint('✅ Interview found: ${_currentInterview!.candidateName}');
      debugPrint('📊 Interview status: ${_currentInterview!.status}');
      debugPrint(
        '🎯 Interview responses: ${_currentInterview!.responses.length}',
      );

      // Generate comprehensive report data
      _reportData = _generateReportData(_currentInterview!);

      debugPrint('✅ Report data generated for interview: $interviewId');
    } catch (e) {
      _error = 'Failed to load interview data: $e';
      debugPrint('❌ Error loading interview data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Generate comprehensive report data from interview
  ReportData _generateReportData(Interview interview) {
    final stats = interview.getPerformanceStats();

    // Calculate overall score (strictly technical based on new requirements)
    final overallScore = interview.technicalScore;
    final technicalScore = interview.technicalScore;

    // Generate detailed question breakdown
    final questionBreakdown = _generateQuestionBreakdown(interview);

    // Calculate recommendation
    final recommendation = interview.getRecommendation();

    return ReportData(
      interview: interview,
      roleName: interview.roleName.isNotEmpty
          ? interview.roleName
          : interview.role.name,
      overallScore: overallScore,
      technicalScore: technicalScore,
      softSkillsScore: interview.softSkillsScore,
      communicationSkills: interview.communicationSkills,
      problemSolvingApproach: interview.problemSolvingApproach,
      culturalFit: interview.culturalFit,
      overallImpression: interview.overallImpression,
      additionalComments: interview.additionalComments,
      recommendation: recommendation,
      totalQuestions: stats['totalQuestions'] as int,
      answeredQuestions: stats['answeredQuestions'] as int,
      correctAnswers: stats['correctAnswers'] as int,
      incorrectAnswers: stats['incorrectAnswers'] as int,
      completionPercentage: stats['completionPercentage'] as double,
      questionBreakdown: questionBreakdown,
      duration: interview.duration?.inMinutes ?? 0,
      voiceRecordingPath: interview.voiceRecordingPath,
      voiceRecordingDurationSeconds: interview.voiceRecordingDurationSeconds,
      verdict: interview.verdict,
    );
  }

  /// Generate detailed question breakdown by category
  List<QuestionBreakdownItem> _generateQuestionBreakdown(Interview interview) {
    final breakdown = <String, QuestionBreakdownItem>{};

    for (final response in interview.responses) {
      final category = response.questionCategory ?? 'Other';

      if (!breakdown.containsKey(category)) {
        breakdown[category] = QuestionBreakdownItem(
          category: category,
          totalQuestions: 0,
          correctAnswers: 0,
          incorrectAnswers: 0,
          responses: [],
        );
      }

      final item = breakdown[category]!;
      breakdown[category] = QuestionBreakdownItem(
        category: category,
        totalQuestions: item.totalQuestions + 1,
        correctAnswers: item.correctAnswers + (response.isCorrect ? 1 : 0),
        incorrectAnswers: item.incorrectAnswers + (response.isCorrect ? 0 : 1),
        responses: [...item.responses, response],
      );
    }

    return breakdown.values.toList()
      ..sort((a, b) => b.totalQuestions.compareTo(a.totalQuestions));
  }

  /// Clear current data
  void clearData() {
    _currentInterview = null;
    _reportData = null;
    _error = null;
    notifyListeners();
  }
}

/// Comprehensive report data model
class ReportData {
  final Interview interview;
  final String roleName;
  final double overallScore;
  final double technicalScore;
  final double? softSkillsScore;
  final int communicationSkills;
  final int problemSolvingApproach;
  final int culturalFit;
  final int overallImpression;
  final String additionalComments;
  final String recommendation;
  final int totalQuestions;
  final int answeredQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final double completionPercentage;
  final List<QuestionBreakdownItem> questionBreakdown;
  final int duration;

  // Audio recording fields
  final String? voiceRecordingPath;
  final int? voiceRecordingDurationSeconds;
  final InterviewVerdict? verdict;

  const ReportData({
    required this.interview,
    required this.roleName,
    required this.overallScore,
    required this.technicalScore,
    this.softSkillsScore,
    this.communicationSkills = 0,
    this.problemSolvingApproach = 0,
    this.culturalFit = 0,
    this.overallImpression = 0,
    this.additionalComments = '',
    required this.recommendation,
    required this.totalQuestions,
    required this.answeredQuestions,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.completionPercentage,
    required this.questionBreakdown,
    required this.duration,
    this.voiceRecordingPath,
    this.voiceRecordingDurationSeconds,
    this.verdict,
  });
}

/// Question breakdown by category
class QuestionBreakdownItem {
  final String category;
  final int totalQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final List<QuestionResponse> responses;

  const QuestionBreakdownItem({
    required this.category,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.responses,
  });

  double get accuracy =>
      totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0.0;
}
