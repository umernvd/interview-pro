import 'package:flutter/foundation.dart';
import '../../shared/domain/entities/interview_question.dart';

/// Validator for Appwrite migration data
class AppwriteMigrationValidator {
  /// Validates that all questions have required fields for Appwrite
  static Map<String, dynamic> validateQuestionsForAppwrite(
    List<InterviewQuestion> questions,
  ) {
    debugPrint('🔍 Validating ${questions.length} questions for Appwrite...');

    final errors = <String>[];
    final warnings = <String>[];
    final stats = <String, int>{
      'total': questions.length,
      'withExperienceLevel': 0,
      'withRoleSpecific': 0,
      'byDifficulty': 0,
      'byCategory': 0,
    };

    final categoryCount = <String, int>{};
    final difficultyCount = <String, int>{};
    final roleCount = <String, int>{};
    final levelCount = <String, int>{};

    for (final question in questions) {
      // Validate required fields
      if (question.id.isEmpty) {
        errors.add('Question has empty id');
      }
      if (question.question.isEmpty) {
        errors.add('Question ${question.id} has empty question text');
      }
      if (question.category.isEmpty) {
        errors.add('Question ${question.id} has empty category');
      }
      if (question.difficulty.isEmpty) {
        errors.add('Question ${question.id} has empty difficulty');
      }
      if (question.evaluationCriteria.isEmpty) {
        errors.add('Question ${question.id} has empty evaluationCriteria');
      }

      // Validate field values
      if (![
        'beginner',
        'intermediate',
        'advanced',
      ].contains(question.difficulty.toLowerCase())) {
        errors.add(
          'Question ${question.id} has invalid difficulty: ${question.difficulty}',
        );
      }

      if (![
        'technical',
        'behavioral',
        'leadership',
        'role-specific',
      ].contains(question.category.toLowerCase())) {
        errors.add(
          'Question ${question.id} has invalid category: ${question.category}',
        );
      }

      // Check optional fields
      if (question.experienceLevel != null &&
          ![
            'intern',
            'associate',
            'senior',
          ].contains(question.experienceLevel!.toLowerCase())) {
        errors.add(
          'Question ${question.id} has invalid experienceLevel: ${question.experienceLevel}',
        );
      }

      // Collect statistics
      if (question.experienceLevel != null) {
        stats['withExperienceLevel'] = stats['withExperienceLevel']! + 1;
        levelCount[question.experienceLevel!] =
            (levelCount[question.experienceLevel!] ?? 0) + 1;
      } else if (question.category.toLowerCase() == 'role-specific') {
        warnings.add(
          'Role-specific question ${question.id} missing experienceLevel',
        );
      }

      if (question.roleSpecific != null) {
        stats['withRoleSpecific'] = stats['withRoleSpecific']! + 1;
        roleCount[question.roleSpecific!] =
            (roleCount[question.roleSpecific!] ?? 0) + 1;
      }

      categoryCount[question.category] =
          (categoryCount[question.category] ?? 0) + 1;
      difficultyCount[question.difficulty] =
          (difficultyCount[question.difficulty] ?? 0) + 1;
    }

    // Print validation results
    debugPrint('✅ Validation Results:');
    debugPrint('📊 Total Questions: ${stats['total']}');
    debugPrint('📊 With Experience Level: ${stats['withExperienceLevel']}');
    debugPrint('📊 With Role Specific: ${stats['withRoleSpecific']}');

    debugPrint('\n📈 By Category:');
    categoryCount.forEach((category, count) {
      debugPrint('  - $category: $count');
    });

    debugPrint('\n📈 By Difficulty:');
    difficultyCount.forEach((difficulty, count) {
      debugPrint('  - $difficulty: $count');
    });

    debugPrint('\n📈 By Experience Level:');
    levelCount.forEach((level, count) {
      debugPrint('  - $level: $count');
    });

    if (roleCount.isNotEmpty) {
      debugPrint('\n📈 By Role:');
      roleCount.forEach((role, count) {
        debugPrint('  - $role: $count');
      });
    }

    if (errors.isNotEmpty) {
      debugPrint('\n❌ Errors Found (${errors.length}):');
      for (final error in errors) {
        debugPrint('  - $error');
      }
    } else {
      debugPrint('\n✅ No Errors Found');
    }

    if (warnings.isNotEmpty) {
      debugPrint('\n⚠️ Warnings (${warnings.length}):');
      for (final warning in warnings) {
        debugPrint('  - $warning');
      }
    }

    return {
      'isValid': errors.isEmpty,
      'errorCount': errors.length,
      'warningCount': warnings.length,
      'errors': errors,
      'warnings': warnings,
      'stats': stats,
      'categoryCount': categoryCount,
      'difficultyCount': difficultyCount,
      'levelCount': levelCount,
      'roleCount': roleCount,
    };
  }

  /// Validates Appwrite schema matches expected structure
  static Map<String, dynamic> validateAppwriteSchema(
    Map<String, dynamic> schemaAttributes,
  ) {
    debugPrint('🔍 Validating Appwrite schema...');

    final requiredFields = [
      'question',
      'category',
      'difficulty',
      'evaluationCriteria',
      'isActive',
      'createdAt',
      'updatedAt',
    ];

    final optionalFields = ['roleSpecific', 'experienceLevel'];

    final obsoleteFields = ['sampleAnswer', 'expectedDuration', 'tags'];

    final errors = <String>[];
    final warnings = <String>[];

    // Check required fields
    for (final field in requiredFields) {
      if (!schemaAttributes.containsKey(field)) {
        errors.add('Missing required field: $field');
      }
    }

    // Check optional fields
    for (final field in optionalFields) {
      if (!schemaAttributes.containsKey(field)) {
        warnings.add('Missing optional field: $field');
      }
    }

    // Check for obsolete fields
    for (final field in obsoleteFields) {
      if (schemaAttributes.containsKey(field)) {
        errors.add('Obsolete field still present: $field (should be removed)');
      }
    }

    debugPrint('✅ Schema Validation Results:');
    debugPrint('📊 Required Fields: ${requiredFields.length}');
    debugPrint('📊 Optional Fields: ${optionalFields.length}');
    debugPrint('📊 Obsolete Fields to Remove: ${obsoleteFields.length}');

    if (errors.isNotEmpty) {
      debugPrint('\n❌ Schema Errors (${errors.length}):');
      for (final error in errors) {
        debugPrint('  - $error');
      }
    } else {
      debugPrint('\n✅ No Schema Errors');
    }

    if (warnings.isNotEmpty) {
      debugPrint('\n⚠️ Schema Warnings (${warnings.length}):');
      for (final warning in warnings) {
        debugPrint('  - $warning');
      }
    }

    return {
      'isValid': errors.isEmpty,
      'errorCount': errors.length,
      'warningCount': warnings.length,
      'errors': errors,
      'warnings': warnings,
    };
  }

  /// Generates a migration report
  static String generateMigrationReport(List<InterviewQuestion> questions) {
    final validation = validateQuestionsForAppwrite(questions);

    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('APPWRITE MIGRATION REPORT - PHASE 4A');
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('');

    buffer.writeln('📊 STATISTICS:');
    buffer.writeln('Total Questions: ${validation['stats']['total']}');
    buffer.writeln(
      'With Experience Level: ${validation['stats']['withExperienceLevel']}',
    );
    buffer.writeln(
      'With Role Specific: ${validation['stats']['withRoleSpecific']}',
    );
    buffer.writeln('');

    buffer.writeln('📈 BY CATEGORY:');
    (validation['categoryCount'] as Map).forEach((category, count) {
      buffer.writeln('  $category: $count');
    });
    buffer.writeln('');

    buffer.writeln('📈 BY DIFFICULTY:');
    (validation['difficultyCount'] as Map).forEach((difficulty, count) {
      buffer.writeln('  $difficulty: $count');
    });
    buffer.writeln('');

    buffer.writeln('📈 BY EXPERIENCE LEVEL:');
    (validation['levelCount'] as Map).forEach((level, count) {
      buffer.writeln('  $level: $count');
    });
    buffer.writeln('');

    if ((validation['roleCount'] as Map).isNotEmpty) {
      buffer.writeln('📈 BY ROLE:');
      (validation['roleCount'] as Map).forEach((role, count) {
        buffer.writeln('  $role: $count');
      });
      buffer.writeln('');
    }

    buffer.writeln('✅ VALIDATION STATUS:');
    buffer.writeln('Valid: ${validation['isValid'] ? 'YES ✅' : 'NO ❌'}');
    buffer.writeln('Errors: ${validation['errorCount']}');
    buffer.writeln('Warnings: ${validation['warningCount']}');
    buffer.writeln('');

    if ((validation['errors'] as List).isNotEmpty) {
      buffer.writeln('❌ ERRORS:');
      for (final error in validation['errors'] as List) {
        buffer.writeln('  - $error');
      }
      buffer.writeln('');
    }

    if ((validation['warnings'] as List).isNotEmpty) {
      buffer.writeln('⚠️ WARNINGS:');
      for (final warning in validation['warnings'] as List) {
        buffer.writeln('  - $warning');
      }
      buffer.writeln('');
    }

    buffer.writeln('═══════════════════════════════════════════════════════');

    return buffer.toString();
  }
}
