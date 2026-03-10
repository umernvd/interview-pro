import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/services/appwrite_service.dart';
import '../../../core/providers/auth_state_provider.dart';
import '../../domain/entities/interview_question.dart';
import '../../domain/entities/question_category.dart';

/// Abstract remote data source for interview questions
abstract class InterviewQuestionRemoteDatasource {
  Future<bool> hasQuestions();
  Future<bool> hasCategories();
  Future<List<InterviewQuestion>> getQuestions({
    String? category,
    String? difficulty,
    String? roleSpecific,
    String? experienceLevel,
    List<String>? tags,
    int limit = 100,
  });
  Future<List<InterviewQuestion>> getQuestionsByCategory(String category);
  Future<List<InterviewQuestion>> getQuestionsByDifficulty(String difficulty);
  Future<List<InterviewQuestion>> getQuestionsByRole(String role);
  Future<List<InterviewQuestion>> getRandomQuestions({
    required int count,
    String? category,
    String? difficulty,
    String? roleSpecific,
  });
  Future<InterviewQuestion> createQuestion(InterviewQuestion question);
  Future<InterviewQuestion> updateQuestion(InterviewQuestion question);
  Future<void> deleteQuestion(String questionId);
  Future<List<QuestionCategoryEntity>> getCategories();
  Future<QuestionCategoryEntity> createCategory(
    QuestionCategoryEntity category,
  );
  Future<List<InterviewQuestion>> bulkCreateQuestions(
    List<Map<String, dynamic>> questionsData,
  );
  Future<List<QuestionCategoryEntity>> bulkCreateCategories(
    List<Map<String, dynamic>> categoriesData,
  );
  Future<Map<String, dynamic>> getQuestionStats();
}

/// Implementation of remote data source for interview questions using Appwrite
class InterviewQuestionRemoteDatasourceImpl
    implements InterviewQuestionRemoteDatasource {
  final AppwriteService _appwriteService;
  final AuthStateProvider _authStateProvider;
  late final Databases _databases;

  // Collection IDs
  static const String questionsCollectionId = 'questions';
  static const String categoriesCollectionId = 'question_categories';

  // Next.js API endpoint for random questions
  static const String _randomQuestionsApiUrl =
      'https://harlan-sheaflike-raymond.ngrok-free.dev/api/questions/random';

  InterviewQuestionRemoteDatasourceImpl(
    this._appwriteService,
    this._authStateProvider,
  ) {
    _databases = _appwriteService.databases;
  }

  @override
  /// Check if questions collection exists and has data
  Future<bool> hasQuestions() async {
    try {
      final response = await _databases.listDocuments(
        databaseId: _appwriteService.databaseId,
        collectionId: questionsCollectionId,
        queries: [Query.limit(1)],
      );
      return response.documents.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking questions existence: $e');
      return false;
    }
  }

  @override
  /// Check if categories collection exists and has data
  Future<bool> hasCategories() async {
    try {
      final response = await _databases.listDocuments(
        databaseId: _appwriteService.databaseId,
        collectionId: categoriesCollectionId,
        queries: [Query.limit(1)],
      );
      return response.documents.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking categories existence: $e');
      return false;
    }
  }

  @override
  /// Get all interview questions with tenant isolation
  Future<List<InterviewQuestion>> getQuestions({
    String? category,
    String? difficulty,
    String? roleSpecific,
    String? experienceLevel,
    List<String>? tags,
    int limit = 100,
  }) async {
    try {
      // Validate auth state for tenant isolation
      final companyId = _authStateProvider.companyId;
      if (companyId == null) {
        throw Exception('User not authenticated: companyId is null');
      }

      final queries = <String>[
        Query.limit(limit),
        Query.equal('isActive', true),
        Query.equal('companyId', companyId), // TENANT ISOLATION
        Query.orderDesc('\$createdAt'),
      ];

      // Add filters
      if (category != null) {
        queries.add(Query.equal('category', category));
      }
      if (difficulty != null) {
        queries.add(Query.equal('difficulty', difficulty));
      }
      if (roleSpecific != null) {
        queries.add(Query.equal('roleSpecific', roleSpecific));
      }
      if (experienceLevel != null) {
        queries.add(Query.equal('experienceLevel', experienceLevel));
      }

      final response = await _databases.listDocuments(
        databaseId: _appwriteService.databaseId,
        collectionId: questionsCollectionId,
        queries: queries,
      );

      return response.documents
          .map((doc) => InterviewQuestion.fromJson(doc.data))
          .where((question) {
            // Additional filtering for tags if provided
            if (tags != null && tags.isNotEmpty) {
              return question.hasAnyTag(tags);
            }
            return true;
          })
          .toList();
    } catch (e) {
      debugPrint('Error fetching questions: $e');
      throw Exception('Failed to fetch questions: $e');
    }
  }

  @override
  /// Get questions by category
  Future<List<InterviewQuestion>> getQuestionsByCategory(
    String category,
  ) async {
    return getQuestions(category: category);
  }

  @override
  /// Get questions by difficulty
  Future<List<InterviewQuestion>> getQuestionsByDifficulty(
    String difficulty,
  ) async {
    return getQuestions(difficulty: difficulty);
  }

  @override
  /// Get questions by role
  Future<List<InterviewQuestion>> getQuestionsByRole(String role) async {
    return getQuestions(roleSpecific: role);
  }

  /// Get questions by experience level
  Future<List<InterviewQuestion>> getQuestionsByExperienceLevel(
    String experienceLevel,
  ) async {
    return getQuestions(experienceLevel: experienceLevel);
  }

  @override
  /// Get random questions for interview via Next.js API
  Future<List<InterviewQuestion>> getRandomQuestions({
    required int count,
    String? category,
    String? difficulty,
    String? roleSpecific,
    String? experienceLevel,
  }) async {
    try {
      // Validate auth state
      final companyId = _authStateProvider.companyId;
      if (companyId == null) {
        throw Exception('User not authenticated: companyId is null');
      }

      // Build query parameters
      final queryParams = <String, String>{
        'companyId': companyId,
        'roleId': ?roleSpecific,
        'experienceLevelId': ?experienceLevel,
      };

      // Build URL with query parameters
      final uri = Uri.parse(
        _randomQuestionsApiUrl,
      ).replace(queryParameters: queryParams);

      debugPrint('🔄 Fetching random questions from: $uri');

      // Make HTTP GET request with ngrok bypass header
      final response = await http
          .get(
            uri,
            headers: {
              'ngrok-skip-browser-warning': 'true',
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw Exception('Request timeout: API did not respond'),
          );

      // Handle response
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        // Parse the JSON array into InterviewQuestion objects
        final List<dynamic> questionsJson = jsonData is List
            ? jsonData
            : (jsonData['questions'] ?? []);

        if (questionsJson.isEmpty) {
          throw Exception('No questions returned from API');
        }

        final questions = questionsJson
            .map((q) => InterviewQuestion.fromJson(q as Map<String, dynamic>))
            .toList();

        debugPrint(
          '✅ Successfully fetched ${questions.length} random questions from API',
        );
        return questions;
      } else {
        final errorBody = response.body;
        debugPrint('❌ API error (${response.statusCode}): $errorBody');
        throw Exception(
          'Failed to fetch questions: ${response.statusCode} - $errorBody',
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching random questions: $e');
      throw Exception('Failed to fetch random questions: $e');
    }
  }

  @override
  /// Create a new question
  Future<InterviewQuestion> createQuestion(InterviewQuestion question) async {
    try {
      final response = await _databases.createDocument(
        databaseId: _appwriteService.databaseId,
        collectionId: questionsCollectionId,
        documentId: question.id, // Use the question's ID as document ID
        data: question.toJson(),
      );

      return InterviewQuestion.fromJson(response.data);
    } catch (e) {
      debugPrint('Error creating question: $e');
      throw Exception('Failed to create question: $e');
    }
  }

  @override
  /// Update an existing question
  Future<InterviewQuestion> updateQuestion(InterviewQuestion question) async {
    try {
      final response = await _databases.updateDocument(
        databaseId: _appwriteService.databaseId,
        collectionId: questionsCollectionId,
        documentId: question.id,
        data: question.copyWith(updatedAt: DateTime.now()).toJson(),
      );

      return InterviewQuestion.fromJson(response.data);
    } catch (e) {
      debugPrint('Error updating question: $e');
      throw Exception('Failed to update question: $e');
    }
  }

  @override
  /// Delete a question
  Future<void> deleteQuestion(String questionId) async {
    try {
      await _databases.deleteDocument(
        databaseId: _appwriteService.databaseId,
        collectionId: questionsCollectionId,
        documentId: questionId,
      );
    } catch (e) {
      debugPrint('Error deleting question: $e');
      throw Exception('Failed to delete question: $e');
    }
  }

  @override
  /// Get all question categories with tenant isolation
  Future<List<QuestionCategoryEntity>> getCategories() async {
    try {
      // Validate auth state for tenant isolation
      final companyId = _authStateProvider.companyId;
      if (companyId == null) {
        throw Exception('User not authenticated: companyId is null');
      }

      final response = await _databases.listDocuments(
        databaseId: _appwriteService.databaseId,
        collectionId: categoriesCollectionId,
        queries: [
          Query.equal('isActive', true),
          Query.equal('companyId', companyId), // TENANT ISOLATION
          Query.orderAsc('name'),
        ],
      );

      return response.documents
          .map((doc) => QuestionCategoryEntity.fromJson(doc.data))
          .toList();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      throw Exception('Failed to fetch categories: $e');
    }
  }

  @override
  /// Create a new category
  Future<QuestionCategoryEntity> createCategory(
    QuestionCategoryEntity category,
  ) async {
    try {
      final response = await _databases.createDocument(
        databaseId: _appwriteService.databaseId,
        collectionId: categoriesCollectionId,
        documentId: ID.unique(),
        data: category.toJson(),
      );

      return QuestionCategoryEntity.fromJson(response.data);
    } catch (e) {
      debugPrint('Error creating category: $e');
      throw Exception('Failed to create category: $e');
    }
  }

  @override
  /// Bulk create questions from JSON data
  Future<List<InterviewQuestion>> bulkCreateQuestions(
    List<Map<String, dynamic>> questionsData,
  ) async {
    final createdQuestions = <InterviewQuestion>[];

    for (final questionData in questionsData) {
      try {
        final question = InterviewQuestion(
          id: questionData['id'],
          question: questionData['question'],
          category: questionData['category'],
          difficulty: questionData['difficulty'],
          evaluationCriteria: List<String>.from(
            questionData['evaluationCriteria'],
          ),
          roleSpecific: questionData['roleSpecific'],
          experienceLevel: questionData['experienceLevel'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final createdQuestion = await createQuestion(question);
        createdQuestions.add(createdQuestion);

        debugPrint('✅ Created question: ${question.id}');
      } catch (e) {
        debugPrint('❌ Failed to create question ${questionData['id']}: $e');
      }
    }

    return createdQuestions;
  }

  @override
  /// Bulk create categories from JSON data
  Future<List<QuestionCategoryEntity>> bulkCreateCategories(
    List<Map<String, dynamic>> categoriesData,
  ) async {
    final createdCategories = <QuestionCategoryEntity>[];

    for (final categoryData in categoriesData) {
      try {
        final category = QuestionCategoryEntity(
          id: categoryData['id'],
          name: categoryData['name'],
          description: categoryData['description'],
          questionCount: (categoryData['questions'] as List).length,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final createdCategory = await createCategory(category);
        createdCategories.add(createdCategory);

        debugPrint('✅ Created category: ${category.name}');
      } catch (e) {
        debugPrint('❌ Failed to create category ${categoryData['name']}: $e');
      }
    }

    return createdCategories;
  }

  @override
  /// Get question statistics
  Future<Map<String, dynamic>> getQuestionStats() async {
    try {
      final allQuestions = await getQuestions(limit: 1000);

      final stats = <String, dynamic>{
        'totalQuestions': allQuestions.length,
        'byCategory': <String, int>{},
        'byDifficulty': <String, int>{},
      };

      // Calculate statistics
      for (final question in allQuestions) {
        // Count by category
        stats['byCategory'][question.category] =
            (stats['byCategory'][question.category] ?? 0) + 1;

        // Count by difficulty
        stats['byDifficulty'][question.difficulty] =
            (stats['byDifficulty'][question.difficulty] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      debugPrint('Error getting question stats: $e');
      return {
        'totalQuestions': 0,
        'byCategory': <String, int>{},
        'byDifficulty': <String, int>{},
      };
    }
  }
}
