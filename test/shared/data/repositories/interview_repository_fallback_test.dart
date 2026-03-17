import 'package:flutter_test/flutter_test.dart';
import 'package:interview_pro_app/shared/data/repositories/interview_repository_impl.dart';
import 'package:interview_pro_app/shared/domain/entities/entities.dart';

void main() {
  group('InterviewRepository Fallback Tests', () {
    late InterviewRepositoryImpl repository;

    setUp(() {
      repository = InterviewRepositoryImpl();
    });

    test(
      'should continue working with in-memory storage when persistence fails',
      () async {
        // Create a test interview
        final interview = Interview(
          id: 'test_fallback_001',
          candidateName: 'Test Candidate',
          role: Role(
            id: 'flutter_dev',
            name: 'Flutter Developer',
            icon: 'flutter',
            description: 'Flutter Developer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          level: ExperienceLevel(
            id: 'associate',
            title: 'Associate',
            description: 'Associate Level',
            sortOrder: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          startTime: DateTime.now(),
          lastModified: DateTime.now(),
          responses: [],
          status: InterviewStatus.inProgress,
        );

        // Save interview (should work in-memory even if persistence fails)
        await repository.saveInterview(interview);

        // Verify it's saved in memory
        final retrievedInterview = await repository.getInterviewById(
          'test_fallback_001',
        );
        expect(retrievedInterview, isNotNull);
        expect(retrievedInterview!.candidateName, equals('Test Candidate'));
        expect(retrievedInterview.role.name, equals('Flutter Developer'));

        // Verify it appears in all interviews list
        final allInterviews = await repository.getAllInterviews();
        expect(allInterviews.length, equals(1));
        expect(allInterviews.first.id, equals('test_fallback_001'));
      },
    );

    test('should handle multiple interviews in memory correctly', () async {
      // Create multiple test interviews
      final interviews = [
        Interview(
          id: 'test_001',
          candidateName: 'Candidate 1',
          role: Role(
            id: 'flutter_dev',
            name: 'Flutter Developer',
            icon: 'flutter',
            description: 'Flutter Developer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          level: ExperienceLevel(
            id: 'intern',
            title: 'Intern',
            description: 'Intern Level',
            sortOrder: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          startTime: DateTime.now(),
          lastModified: DateTime.now(),
          responses: [],
          status: InterviewStatus.inProgress,
        ),
        Interview(
          id: 'test_002',
          candidateName: 'Candidate 2',
          role: Role(
            id: 'backend_dev',
            name: 'Backend Developer',
            icon: 'backend',
            description: 'Backend Developer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          level: ExperienceLevel(
            id: 'senior',
            title: 'Senior',
            description: 'Senior Level',
            sortOrder: 2,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          startTime: DateTime.now(),
          lastModified: DateTime.now(),
          responses: [],
          status: InterviewStatus.completed,
        ),
      ];

      // Save all interviews
      for (final interview in interviews) {
        await repository.saveInterview(interview);
      }

      // Verify all are saved
      final allInterviews = await repository.getAllInterviews();
      expect(allInterviews.length, equals(2));

      // Verify individual retrieval
      final interview1 = await repository.getInterviewById('test_001');
      final interview2 = await repository.getInterviewById('test_002');

      expect(interview1?.candidateName, equals('Candidate 1'));
      expect(interview2?.candidateName, equals('Candidate 2'));
    });

    test('should handle interview updates correctly in memory', () async {
      // Create initial interview
      final interview = Interview(
        id: 'test_update_001',
        candidateName: 'Initial Name',
        role: Role(
          id: 'flutter_dev',
          name: 'Flutter Developer',
          icon: 'flutter',
          description: 'Flutter Developer',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        level: ExperienceLevel(
          id: 'associate',
          title: 'Associate',
          description: 'Associate Level',
          sortOrder: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        startTime: DateTime.now(),
        lastModified: DateTime.now(),
        responses: [],
        status: InterviewStatus.inProgress,
      );

      await repository.saveInterview(interview);

      // Update the interview
      final updatedInterview = interview.copyWith(
        candidateName: 'Updated Name',
        status: InterviewStatus.completed,
      );

      await repository.updateInterview(updatedInterview);

      // Verify update
      final retrievedInterview = await repository.getInterviewById(
        'test_update_001',
      );
      expect(retrievedInterview?.candidateName, equals('Updated Name'));
      expect(retrievedInterview?.status, equals(InterviewStatus.completed));
    });
  });
}
