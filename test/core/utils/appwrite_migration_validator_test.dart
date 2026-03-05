import 'package:flutter_test/flutter_test.dart';
import 'package:interview_pro_app/core/utils/appwrite_migration_validator.dart';
import 'package:interview_pro_app/shared/domain/entities/interview_question.dart';

void main() {
  group('AppwriteMigrationValidator Tests', () {
    test('should validate questions with all required fields', () {
      final questions = [
        InterviewQuestion(
          id: 'test_001',
          question: 'Test question?',
          category: 'technical',
          difficulty: 'beginner',
          evaluationCriteria: ['Criteria 1', 'Criteria 2'],
          roleSpecific: 'Flutter Developer',
          experienceLevel: 'intern',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        ),
      ];

      final result = AppwriteMigrationValidator.validateQuestionsForAppwrite(
        questions,
      );

      expect(result['isValid'], true);
      expect(result['errorCount'], 0);
      expect(result['stats']['total'], 1);
      expect(result['stats']['withExperienceLevel'], 1);
    });

    test('should detect missing required fields', () {
      final questions = [
        InterviewQuestion(
          id: '',
          question: '',
          category: '',
          difficulty: '',
          evaluationCriteria: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = AppwriteMigrationValidator.validateQuestionsForAppwrite(
        questions,
      );

      expect(result['isValid'], false);
      expect(result['errorCount'], greaterThan(0));
    });

    test('should detect invalid difficulty values', () {
      final questions = [
        InterviewQuestion(
          id: 'test_001',
          question: 'Test question?',
          category: 'technical',
          difficulty: 'invalid_difficulty',
          evaluationCriteria: ['Criteria 1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = AppwriteMigrationValidator.validateQuestionsForAppwrite(
        questions,
      );

      expect(result['isValid'], false);
      expect(result['errorCount'], greaterThan(0));
    });

    test('should detect invalid category values', () {
      final questions = [
        InterviewQuestion(
          id: 'test_001',
          question: 'Test question?',
          category: 'invalid_category',
          difficulty: 'beginner',
          evaluationCriteria: ['Criteria 1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = AppwriteMigrationValidator.validateQuestionsForAppwrite(
        questions,
      );

      expect(result['isValid'], false);
      expect(result['errorCount'], greaterThan(0));
    });

    test('should detect invalid experience level values', () {
      final questions = [
        InterviewQuestion(
          id: 'test_001',
          question: 'Test question?',
          category: 'technical',
          difficulty: 'beginner',
          evaluationCriteria: ['Criteria 1'],
          experienceLevel: 'invalid_level',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = AppwriteMigrationValidator.validateQuestionsForAppwrite(
        questions,
      );

      expect(result['isValid'], false);
      expect(result['errorCount'], greaterThan(0));
    });

    test(
      'should warn about role-specific questions without experience level',
      () {
        final questions = [
          InterviewQuestion(
            id: 'test_001',
            question: 'Test question?',
            category: 'role-specific',
            difficulty: 'beginner',
            evaluationCriteria: ['Criteria 1'],
            roleSpecific: 'Flutter Developer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final result = AppwriteMigrationValidator.validateQuestionsForAppwrite(
          questions,
        );

        expect(result['warningCount'], greaterThan(0));
      },
    );

    test('should generate migration report', () {
      final questions = [
        InterviewQuestion(
          id: 'test_001',
          question: 'Test question 1?',
          category: 'technical',
          difficulty: 'beginner',
          evaluationCriteria: ['Criteria 1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        InterviewQuestion(
          id: 'test_002',
          question: 'Test question 2?',
          category: 'behavioral',
          difficulty: 'intermediate',
          evaluationCriteria: ['Criteria 1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final report = AppwriteMigrationValidator.generateMigrationReport(
        questions,
      );

      expect(report, contains('APPWRITE MIGRATION REPORT'));
      expect(report, contains('Total Questions: 2'));
      expect(report, contains('technical'));
      expect(report, contains('behavioral'));
    });

    test('should count questions by category correctly', () {
      final questions = [
        InterviewQuestion(
          id: 'tech_001',
          question: 'Tech question?',
          category: 'technical',
          difficulty: 'beginner',
          evaluationCriteria: ['Criteria 1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        InterviewQuestion(
          id: 'tech_002',
          question: 'Tech question 2?',
          category: 'technical',
          difficulty: 'intermediate',
          evaluationCriteria: ['Criteria 1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        InterviewQuestion(
          id: 'behav_001',
          question: 'Behavioral question?',
          category: 'behavioral',
          difficulty: 'beginner',
          evaluationCriteria: ['Criteria 1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = AppwriteMigrationValidator.validateQuestionsForAppwrite(
        questions,
      );

      expect(result['categoryCount']['technical'], 2);
      expect(result['categoryCount']['behavioral'], 1);
    });

    test('should count questions by difficulty correctly', () {
      final questions = [
        InterviewQuestion(
          id: 'test_001',
          question: 'Beginner question?',
          category: 'technical',
          difficulty: 'beginner',
          evaluationCriteria: ['Criteria 1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        InterviewQuestion(
          id: 'test_002',
          question: 'Intermediate question?',
          category: 'technical',
          difficulty: 'intermediate',
          evaluationCriteria: ['Criteria 1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        InterviewQuestion(
          id: 'test_003',
          question: 'Advanced question?',
          category: 'technical',
          difficulty: 'advanced',
          evaluationCriteria: ['Criteria 1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = AppwriteMigrationValidator.validateQuestionsForAppwrite(
        questions,
      );

      expect(result['difficultyCount']['beginner'], 1);
      expect(result['difficultyCount']['intermediate'], 1);
      expect(result['difficultyCount']['advanced'], 1);
    });
  });
}
