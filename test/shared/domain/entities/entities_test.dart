import 'package:flutter_test/flutter_test.dart';
import 'package:interview_pro_app/shared/domain/entities/entities.dart';

void main() {
  group('Core Entities Tests', () {
    group('Role Entity', () {
      test('should create Role with correct properties', () {
        final role = Role(
          id: 'flutter_dev',
          name: 'Flutter Developer',
          icon: 'flutter',
          description: 'Flutter Developer',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(role.id, 'flutter_dev');
        expect(role.name, 'Flutter Developer');
        expect(role.icon, 'flutter');
        expect(role.description, 'Flutter Developer');
      });

      test('should create multiple Role instances', () {
        final roles = [
          Role(
            id: 'flutter_dev',
            name: 'Flutter Developer',
            icon: 'flutter',
            description: 'Flutter Developer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Role(
            id: 'backend_dev',
            name: 'Backend Developer',
            icon: 'backend',
            description: 'Backend Developer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Role(
            id: 'frontend_dev',
            name: 'Frontend Developer',
            icon: 'frontend',
            description: 'Frontend Developer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        expect(roles.length, 3);
        expect(roles[0].name, 'Flutter Developer');
        expect(roles[1].name, 'Backend Developer');
        expect(roles[2].name, 'Frontend Developer');
      });
    });

    group('ExperienceLevel Entity', () {
      test('should create ExperienceLevel with correct properties', () {
        final level = ExperienceLevel(
          id: 'intern',
          title: 'Intern',
          description: 'Intern Level',
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(level.id, 'intern');
        expect(level.title, 'Intern');
        expect(level.description, 'Intern Level');
        expect(level.sortOrder, 0);
      });

      test('should create multiple ExperienceLevel instances', () {
        final levels = [
          ExperienceLevel(
            id: 'intern',
            title: 'Intern',
            description: 'Intern Level',
            sortOrder: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          ExperienceLevel(
            id: 'associate',
            title: 'Associate',
            description: 'Associate Level',
            sortOrder: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          ExperienceLevel(
            id: 'senior',
            title: 'Senior',
            description: 'Senior Level',
            sortOrder: 2,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        expect(levels.length, 3);
        expect(levels[0].title, 'Intern');
        expect(levels[1].title, 'Associate');
        expect(levels[2].title, 'Senior');
      });
    });

    group('QuestionCategory enum', () {
      test('QuestionCategory enum should have correct display names', () {
        expect(
          QuestionCategory.programmingFundamentals.displayName,
          'Programming Fundamentals',
        );
        expect(
          QuestionCategory.roleSpecificTechnical.displayName,
          'Role-Specific Technical',
        );
        expect(
          QuestionCategory.modernDevelopmentPractices.displayName,
          'Modern Development Practices',
        );
        expect(QuestionCategory.softSkills.displayName, 'Soft Skills');
      });
    });

    group('InterviewStatus enum', () {
      test('InterviewStatus enum should have correct display names', () {
        expect(InterviewStatus.notStarted.displayName, 'Not Started');
        expect(InterviewStatus.inProgress.displayName, 'In Progress');
        expect(InterviewStatus.completed.displayName, 'Completed');
        expect(InterviewStatus.cancelled.displayName, 'Cancelled');
      });
    });

    group('QuestionResponse', () {
      test('should create QuestionResponse with required fields', () {
        final timestamp = DateTime.now();
        final response = QuestionResponse(
          questionId: 'q1',
          questionText: 'What is Flutter?',
          isCorrect: true,
          timestamp: timestamp,
        );

        expect(response.questionId, 'q1');
        expect(response.questionText, 'What is Flutter?');
        expect(response.isCorrect, true);
        expect(response.notes, null);
        expect(response.timestamp, timestamp);
        expect(response.hasNotes, false);
        expect(response.resultText, 'Correct');
      });

      test('should create QuestionResponse with notes', () {
        final timestamp = DateTime.now();
        final response = QuestionResponse(
          questionId: 'q1',
          questionText: 'Explain state management in Flutter',
          isCorrect: false,
          notes: 'Candidate struggled with the concept',
          timestamp: timestamp,
        );

        expect(response.hasNotes, true);
        expect(response.resultText, 'Incorrect');
        expect(
          response.summary,
          'Incorrect - Candidate struggled with the concept',
        );
      });

      test('should support copyWith', () {
        final timestamp = DateTime.now();
        final original = QuestionResponse(
          questionId: 'q1',
          questionText: 'What is Dart?',
          isCorrect: false,
          timestamp: timestamp,
        );

        final updated = original.copyWith(
          isCorrect: true,
          notes: 'Good answer',
        );

        expect(updated.questionId, 'q1');
        expect(updated.questionText, 'What is Dart?');
        expect(updated.isCorrect, true);
        expect(updated.notes, 'Good answer');
        expect(updated.timestamp, timestamp);
      });
    });

    group('Interview', () {
      test('should create Interview with required fields', () {
        final startTime = DateTime.now();
        final responses = <QuestionResponse>[];
        final role = Role(
          id: 'flutter_dev',
          name: 'Flutter Developer',
          icon: 'flutter',
          description: 'Flutter Developer',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final level = ExperienceLevel(
          id: 'associate',
          title: 'Associate',
          description: 'Associate Level',
          sortOrder: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final interview = Interview(
          id: 'i1',
          candidateName: 'John Doe',
          role: role,
          level: level,
          startTime: startTime,
          lastModified: startTime,
          responses: responses,
          status: InterviewStatus.notStarted,
        );

        expect(interview.id, 'i1');
        expect(interview.candidateName, 'John Doe');
        expect(interview.role, role);
        expect(interview.level, level);
        expect(interview.startTime, startTime);
        expect(interview.endTime, null);
        expect(interview.responses, responses);
        expect(interview.status, InterviewStatus.notStarted);
        expect(interview.overallScore, null);
      });

      test('should calculate duration correctly', () {
        final startTime = DateTime.now();
        final endTime = startTime.add(const Duration(hours: 1, minutes: 30));
        final role = Role(
          id: 'flutter_dev',
          name: 'Flutter Developer',
          icon: 'flutter',
          description: 'Flutter Developer',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final level = ExperienceLevel(
          id: 'associate',
          title: 'Associate',
          description: 'Associate Level',
          sortOrder: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final interview = Interview(
          id: 'i1',
          candidateName: 'John Doe',
          role: role,
          level: level,
          startTime: startTime,
          endTime: endTime,
          lastModified: endTime,
          responses: [],
          status: InterviewStatus.completed,
        );

        expect(interview.duration, const Duration(hours: 1, minutes: 30));
      });

      test('should check status correctly', () {
        final role = Role(
          id: 'flutter_dev',
          name: 'Flutter Developer',
          icon: 'flutter',
          description: 'Flutter Developer',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final level = ExperienceLevel(
          id: 'associate',
          title: 'Associate',
          description: 'Associate Level',
          sortOrder: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final interview = Interview(
          id: 'i1',
          candidateName: 'John Doe',
          role: role,
          level: level,
          startTime: DateTime.now(),
          lastModified: DateTime.now(),
          responses: [],
          status: InterviewStatus.completed,
        );

        expect(interview.isCompleted, true);
        expect(interview.isInProgress, false);
      });

      test('should support copyWith', () {
        final startTime = DateTime.now();
        final role = Role(
          id: 'flutter_dev',
          name: 'Flutter Developer',
          icon: 'flutter',
          description: 'Flutter Developer',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final level = ExperienceLevel(
          id: 'associate',
          title: 'Associate',
          description: 'Associate Level',
          sortOrder: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final original = Interview(
          id: 'i1',
          candidateName: 'John Doe',
          role: role,
          level: level,
          startTime: startTime,
          lastModified: startTime,
          responses: [],
          status: InterviewStatus.notStarted,
        );

        final updated = original.copyWith(
          status: InterviewStatus.inProgress,
          overallScore: 85.5,
        );

        expect(updated.id, 'i1');
        expect(updated.candidateName, 'John Doe');
        expect(updated.status, InterviewStatus.inProgress);
        expect(updated.overallScore, 85.5);
        expect(updated.startTime, startTime);
      });
    });
  });
}
