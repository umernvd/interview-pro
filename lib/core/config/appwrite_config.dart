import 'setup_helper.dart';

/// Appwrite configuration constants
class AppwriteConfig {
  // Project configuration - update in setup_helper.dart
  static String get projectId => SetupHelper.projectId;
  static const String endpoint = 'https://fra.cloud.appwrite.io/v1';

  // Database configuration
  static const String databaseId = 'interview_pro_db';

  // Collection IDs
  static const String rolesCollectionId = 'roles';
  static const String candidatesCollectionId = 'candidates';
  static const String interviewsCollectionId = 'interviews';
  static const String questionsCollectionId = 'questions';
  static const String evaluationsCollectionId = 'evaluations';
  static const String interviewersCollectionId = 'interviewers';

  /// Check if Appwrite is properly configured
  static bool get isConfigured => SetupHelper.isSetupComplete;

  /// Get configuration status message
  static String get statusMessage => SetupHelper.setupStatusMessage;

  // Development Fallbacks
  static const String testCompanyId = '699d77ca003617180a13';
  static const String testInterviewerId = 'test_interviewer_123';
}
