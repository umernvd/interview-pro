import '../entities/entities.dart';

/// Repository interface for managing interview data
abstract class InterviewRepository {
  /// Get all interviews
  Future<List<Interview>> getAllInterviews();

  /// Get interview by ID
  Future<Interview?> getInterviewById(String id);

  /// Save interview
  Future<void> saveInterview(Interview interview);

  /// Update interview
  Future<void> updateInterview(Interview interview);

  /// Delete interview
  Future<void> deleteInterview(String id);

  /// Get interviews by status
  Future<List<Interview>> getInterviewsByStatus(InterviewStatus status);

  /// Get interviews by role
  Future<List<Interview>> getInterviewsByRole(Role role);

  /// Get interviews by level
  Future<List<Interview>> getInterviewsByLevel(ExperienceLevel level);

  /// Get recent interviews
  Future<List<Interview>> getRecentInterviews({int limit = 10});

  /// Get interviews within date range
  Future<List<Interview>> getInterviewsInDateRange(
    DateTime startDate,
    DateTime endDate,
  );

  /// Get total count of interviews
  Future<int> getInterviewCount();

  /// Get count of interviews by status
  Future<int> getInterviewCountByStatus(InterviewStatus status);

  /// Check if interview exists
  Future<bool> interviewExists(String id);

  /// Get interviews with performance above threshold
  Future<List<Interview>> getHighPerformingInterviews({
    double threshold = 70.0,
  });

  /// Get average performance by role
  Future<Map<Role, double>> getAveragePerformanceByRole();

  /// Get average performance by level
  Future<Map<ExperienceLevel, double>> getAveragePerformanceByLevel();

  /// Get interview statistics
  Future<Map<String, dynamic>> getInterviewStatistics();

  /// Save question response (for real-time updates)
  Future<void> saveQuestionResponse(
    String interviewId,
    QuestionResponse response,
  );

  /// Get question responses for an interview
  Future<List<QuestionResponse>> getQuestionResponses(String interviewId);

  /// Update interview progress
  Future<void> updateInterviewProgress(
    String interviewId,
    int currentQuestionIndex,
  );

  /// Get active (in-progress) interviews
  Future<List<Interview>> getActiveInterviews();

  /// Complete interview with final scores
  Future<void> completeInterview(
    String interviewId, {
    required double technicalScore,
    double? softSkillsScore,
    double? overallScore,
  });

  /// Clear all interviews from storage
  Future<void> clearAllInterviews();
}
