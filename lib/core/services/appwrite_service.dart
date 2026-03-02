import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import '../config/appwrite_config.dart';

/// Appwrite service for managing backend operations
class AppwriteService {
  static AppwriteService? _instance;
  late Client _client;
  late Databases _databases;
  late Account _account;

  AppwriteService._internal();

  static AppwriteService get instance {
    _instance ??= AppwriteService._internal();
    return _instance!;
  }

  /// Initialize Appwrite client
  void initialize() {
    _client = Client()
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId);

    _databases = Databases(_client);
    _account = Account(_client);
  }

  /// Perform a silent login using a unified service account to bypass Appwrite auth requirements.
  /// First checks if a session exists to avoid redundant login calls.
  Future<void> performSilentLogin() async {
    try {
      // 1. Check if a session already exists
      await _account.get();
      debugPrint('✅ Appwrite: Already logged in silently.');
    } on AppwriteException catch (e) {
      // 2. If we get a 401 error, it means we are a Guest. Time to log in!
      if (e.code == 401) {
        debugPrint('⏳ Appwrite: No session found. Performing silent login...');
        try {
          await _account.createEmailPasswordSession(
            email: 'interviewer@acme.com', // Service account email
            password: 'acmepassword123', // Service account password
          );
          debugPrint('✅ Appwrite: Silent login successful!');
        } catch (loginError) {
          debugPrint('❌ Appwrite: Silent login failed: $loginError');
        }
      } else {
        debugPrint('❌ Appwrite: Unexpected error checking session: $e');
      }
    } catch (e) {
      debugPrint('❌ Appwrite: Unknown error during silent login check: $e');
    }
  }

  /// Get databases instance
  Databases get databases => _databases;

  /// Get account instance
  Account get account => _account;

  /// Get client instance
  Client get client => _client;

  /// Get database ID for collections
  String get databaseId => AppwriteConfig.databaseId;

  /// Update interview with Google Drive file info
  Future<void> updateInterviewDriveInfo({
    required String interviewId,
    required String driveFileId,
    required String driveFileUrl,
  }) async {
    try {
      await _databases.updateDocument(
        databaseId: databaseId,
        collectionId: AppwriteConfig.interviewsCollectionId,
        documentId: interviewId,
        data: {'driveFileId': driveFileId, 'driveFileUrl': driveFileUrl},
      );
      debugPrint('✅ Updated interview $interviewId with Drive info');
    } catch (e) {
      debugPrint('❌ Failed to update interview with Drive info: $e');
      rethrow;
    }
  }
}
