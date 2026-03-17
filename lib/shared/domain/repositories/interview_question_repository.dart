import '../entities/interview_question.dart';
import '../entities/question_category.dart';

/// Repository interface for interview questions
abstract class InterviewQuestionRepository {
  /// Check if questions exist in the repository
  Future<bool> hasQuestions();

  /// Check if categories exist in the repository
  Future<bool> hasCategories();

  /// Get all interview questions with optional filters
  Future<List<InterviewQuestion>> getQuestions({
    String? category,
    String? difficulty,
    String? roleSpecific,
    List<String>? tags,
    int limit = 100,
  });

  /// Get questions by category
  Future<List<InterviewQuestion>> getQuestionsByCategory(String category);

  /// Get questions by difficulty level
  Future<List<InterviewQuestion>> getQuestionsByDifficulty(String difficulty);

  /// Get questions by role
  Future<List<InterviewQuestion>> getQuestionsByRole(String role);

  /// Get random questions for interview
  Future<List<InterviewQuestion>> getRandomQuestions({
    required int count,
    String? category,
    String? difficulty,
    String? roleSpecific,
    String? experienceLevel,
  });

  /// Create a new question
  Future<InterviewQuestion> createQuestion(InterviewQuestion question);

  /// Update an existing question
  Future<InterviewQuestion> updateQuestion(InterviewQuestion question);

  /// Delete a question
  Future<void> deleteQuestion(String questionId);

  /// Get all question categories
  Future<List<QuestionCategoryEntity>> getCategories();

  /// Create a new category
  Future<QuestionCategoryEntity> createCategory(
    QuestionCategoryEntity category,
  );

  /// Bulk create questions from data
  Future<List<InterviewQuestion>> bulkCreateQuestions(
    List<Map<String, dynamic>> questionsData,
  );

  /// Bulk create categories from data
  Future<List<QuestionCategoryEntity>> bulkCreateCategories(
    List<Map<String, dynamic>> categoriesData,
  );

  /// Get question statistics
  Future<Map<String, dynamic>> getQuestionStats();

  /// Initialize default questions from JSON
  Future<void> initializeDefaultQuestions();
}
