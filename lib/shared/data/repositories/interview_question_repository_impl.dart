import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/interview_question.dart';
import '../../domain/entities/question_category.dart';
import '../../domain/repositories/interview_question_repository.dart';
import '../datasources/interview_question_remote_datasource.dart';

/// Implementation of InterviewQuestionRepository
class InterviewQuestionRepositoryImpl implements InterviewQuestionRepository {
  final InterviewQuestionRemoteDatasource _remoteDatasource;

  InterviewQuestionRepositoryImpl(this._remoteDatasource);

  @override
  Future<bool> hasQuestions() async {
    return await _remoteDatasource.hasQuestions();
  }

  @override
  Future<bool> hasCategories() async {
    return await _remoteDatasource.hasCategories();
  }

  @override
  Future<List<InterviewQuestion>> getQuestions({
    String? category,
    String? difficulty,
    String? roleSpecific,
    List<String>? tags,
    int limit = 100,
  }) async {
    return await _remoteDatasource.getQuestions(
      category: category,
      difficulty: difficulty,
      roleSpecific: roleSpecific,
      tags: tags,
      limit: limit,
    );
  }

  @override
  Future<List<InterviewQuestion>> getQuestionsByCategory(
    String category,
  ) async {
    return await _remoteDatasource.getQuestionsByCategory(category);
  }

  @override
  Future<List<InterviewQuestion>> getQuestionsByDifficulty(
    String difficulty,
  ) async {
    return await _remoteDatasource.getQuestionsByDifficulty(difficulty);
  }

  @override
  Future<List<InterviewQuestion>> getQuestionsByRole(String role) async {
    return await _remoteDatasource.getQuestionsByRole(role);
  }

  @override
  Future<List<InterviewQuestion>> getRandomQuestions({
    required int count,
    String? category,
    String? difficulty,
    String? roleSpecific,
    String? experienceLevel,
  }) async {
    debugPrint(
      '🔍 REPOSITORY - getRandomQuestions called with roleSpecific: $roleSpecific, experienceLevel: $experienceLevel',
    );
    try {
      final questions = await _remoteDatasource.getRandomQuestions(
        count: count,
        category: category,
        difficulty: difficulty,
        roleSpecific: roleSpecific,
        experienceLevel: experienceLevel,
      );
      debugPrint(
        '🔍 REPOSITORY - Datasource returned ${questions.length} questions',
      );
      return questions;
    } catch (e) {
      debugPrint('🚨 REPOSITORY ERROR: $e');
      rethrow;
    }
  }

  @override
  Future<InterviewQuestion> createQuestion(InterviewQuestion question) async {
    return await _remoteDatasource.createQuestion(question);
  }

  @override
  Future<InterviewQuestion> updateQuestion(InterviewQuestion question) async {
    return await _remoteDatasource.updateQuestion(question);
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    return await _remoteDatasource.deleteQuestion(questionId);
  }

  @override
  Future<List<QuestionCategoryEntity>> getCategories() async {
    return await _remoteDatasource.getCategories();
  }

  @override
  Future<QuestionCategoryEntity> createCategory(
    QuestionCategoryEntity category,
  ) async {
    return await _remoteDatasource.createCategory(category);
  }

  @override
  Future<List<InterviewQuestion>> bulkCreateQuestions(
    List<Map<String, dynamic>> questionsData,
  ) async {
    return await _remoteDatasource.bulkCreateQuestions(questionsData);
  }

  @override
  Future<List<QuestionCategoryEntity>> bulkCreateCategories(
    List<Map<String, dynamic>> categoriesData,
  ) async {
    return await _remoteDatasource.bulkCreateCategories(categoriesData);
  }

  @override
  Future<Map<String, dynamic>> getQuestionStats() async {
    return await _remoteDatasource.getQuestionStats();
  }

  @override
  Future<void> initializeDefaultQuestions() async {
    try {
      debugPrint('🔄 Initializing default interview questions...');

      // Check if questions already exist
      final hasExistingQuestions = await hasQuestions();

      if (hasExistingQuestions) {
        debugPrint('✅ Questions already exist, skipping initialization');
        return;
      }

      // Load questions from JSON asset
      final jsonString = await rootBundle.loadString(
        'assets/data/interview_questions.json',
      );
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      final categories = jsonData['categories'] as List<dynamic>;

      // Try to create categories (optional - ignore if collection doesn't exist)
      try {
        final hasExistingCategories = await hasCategories();
        if (!hasExistingCategories) {
          debugPrint('📝 Creating question categories...');
          await bulkCreateCategories(
            categories.map((cat) => cat as Map<String, dynamic>).toList(),
          );
        }
      } catch (e) {
        debugPrint('⚠️ Categories collection not available, skipping: $e');
      }

      // Create questions
      debugPrint('📝 Creating interview questions...');

      // Flatten all questions from all categories
      final allQuestions = <Map<String, dynamic>>[];
      for (final category in categories) {
        final questions = category['questions'] as List<dynamic>;
        allQuestions.addAll(
          questions.map((q) => q as Map<String, dynamic>).toList(),
        );
      }

      await bulkCreateQuestions(allQuestions);

      debugPrint('✅ Default interview questions initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing default questions: $e');
      throw Exception('Failed to initialize default questions: $e');
    }
  }
}
