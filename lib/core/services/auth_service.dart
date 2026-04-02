import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'appwrite_service.dart';
import 'service_locator.dart';
import 'cache_manager.dart';
import '../providers/auth_state_provider.dart';
import '../config/appwrite_config.dart';
import '../../features/auth/data/models/interviewer_model.dart';
import '../../shared/domain/repositories/interview_repository.dart';

/// Service for handling magic auth code authentication
/// Manages login, session restoration, and logout operations
class AuthService {
  final AppwriteService _appwriteService;
  final AuthStateProvider _authStateProvider;
  final FlutterSecureStorage _secureStorage;

  // Storage keys for secure caching
  static const String _companyIdKey = 'auth_company_id';
  static const String _interviewerIdKey = 'auth_interviewer_id';
  static const String _emailKey = 'auth_email';

  // Appwrite collection IDs
  static const String _interviewersCollectionId =
      AppwriteConfig.interviewersCollectionId;

  AuthService(
    this._appwriteService,
    this._authStateProvider, [
    FlutterSecureStorage? secureStorage,
  ]) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Get current authenticated user's email
  String? get currentEmail => _authStateProvider.email;

  /// Get current authenticated user's company ID
  String? get currentCompanyId => _authStateProvider.companyId;

  /// Get current authenticated user's interviewer ID
  String? get currentInterviewerId => _authStateProvider.interviewerId;

  /// Authenticate user with email and 6-digit auth code
  /// Throws Exception if credentials are invalid
  /// Returns void on success (state is updated via AuthStateProvider)
  Future<void> loginWithAuthCode(String email, String authCode) async {
    try {
      // Step 1: Normalize inputs
      final normalizedEmail = _normalizeEmail(email);
      final trimmedAuthCode = _normalizeAuthCode(authCode);

      // Create Appwrite-compatible password (8+ characters required)
      final String appwritePassword = '${trimmedAuthCode}_MagicLogin';

      // Step 2: Query interviewers collection (using original auth code)
      final interviewer = await _queryInterviewersCollection(
        normalizedEmail,
        trimmedAuthCode,
      );

      // Step 3: Check if interviewer was found
      if (interviewer == null) {
        throw Exception("Invalid email or auth code.");
      }

      debugPrint(
        '✅ Interviewer found: id=${interviewer.id}, userId=${interviewer.userId}',
      );

      // Step 4: Handle first-time vs returning user
      if (interviewer.userId == null) {
        // First-time user: Create account, session, and update DB
        await _handleFirstTimeUser(
          normalizedEmail,
          appwritePassword,
          interviewer,
        );
      } else {
        // Returning user: Create session only
        await _handleReturningUser(
          normalizedEmail,
          appwritePassword,
          interviewer,
        );
      }

      // Step 5: Save to cache and update state
      // If the interviewer changed, clear local interview history (device-local data belongs to previous user)
      final previousInterviewerId = _authStateProvider.interviewerId;
      if (previousInterviewerId != null &&
          previousInterviewerId != interviewer.id) {
        debugPrint('🔄 Interviewer changed — clearing local interview history');
        try {
          final sharedPrefs = await SharedPreferences.getInstance();
          await sharedPrefs.remove('stored_interviews');
          await sharedPrefs.remove('stored_responses');
          debugPrint('✅ Local interview history cleared for new user');
        } catch (e) {
          debugPrint('⚠️ Failed to clear local interview history: $e');
        }
        // Clear all cached data (roles, questions, etc.) for company isolation
        CacheManager.clear();
        debugPrint('✅ Cache cleared for company data isolation');
      }

      await _saveToCache(
        normalizedEmail,
        interviewer.companyId,
        interviewer.id,
      );
      _authStateProvider.setAuthState(
        normalizedEmail,
        interviewer.companyId,
        interviewer.id,
      );

      debugPrint('✅ Login successful for $normalizedEmail');
    } on AppwriteException catch (e) {
      debugPrint(
        '❌ Appwrite error during login: ${e.message} (code: ${e.code})',
      );
      _handleAppwriteException(e);
    } on SocketException catch (e) {
      debugPrint('❌ Network error during login: $e');
      throw Exception(
        "Network error. Please check your connection and try again.",
      );
    } catch (e) {
      debugPrint('❌ Unexpected error during login: $e');
      if (e.toString().contains('Invalid email or auth code')) {
        rethrow;
      }
      throw Exception("An unexpected error occurred. Please try again.");
    }
  }

  /// Check for existing session on app startup
  /// Restores authentication state if session exists
  /// Returns true if session was restored, false otherwise
  Future<bool> restoreSessionOnStartup() async {
    try {
      // Check for existing session
      final session = await _appwriteService.account.get();

      debugPrint('✅ Found existing session for user: ${session.email}');

      // Try to retrieve from cache first (offline-capable)
      final cachedData = await _retrieveFromCache();

      if (cachedData['email'] != null &&
          cachedData['companyId'] != null &&
          cachedData['interviewerId'] != null) {
        // Cache exists, use it
        _authStateProvider.setAuthState(
          cachedData['email']!,
          cachedData['companyId']!,
          cachedData['interviewerId']!,
        );

        debugPrint('✅ Restored session from cache (offline-capable)');
        return true;
      }

      // Cache missing, query database
      debugPrint('⚠️ Cache missing, querying database to restore session');
      final normalizedEmail = _normalizeEmail(session.email);

      final response = await _appwriteService.databases.listDocuments(
        databaseId: _appwriteService.databaseId,
        collectionId: _interviewersCollectionId,
        queries: [Query.equal('email', normalizedEmail)],
      );

      if (response.total == 0) {
        debugPrint(
          '❌ No interviewer found for session email - cleaning up ghost session',
        );
        // REQUIREMENT 1: Ghost session cleanup - interviewer profile deleted
        try {
          await _appwriteService.account.deleteSession(sessionId: 'current');
          debugPrint('✅ Deleted ghost session');
        } catch (e) {
          debugPrint('⚠️ Error deleting ghost session: $e');
        }
        return false;
      }

      final interviewer = InterviewerModel.fromDocument(
        response.documents.first.data,
      );

      // Save to cache for future offline restores
      await _saveToCache(
        normalizedEmail,
        interviewer.companyId,
        interviewer.id,
      );

      // Update state
      _authStateProvider.setAuthState(
        normalizedEmail,
        interviewer.companyId,
        interviewer.id,
      );

      debugPrint('✅ Restored session from database and saved to cache');
      return true;
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        debugPrint('ℹ️ No existing session found');
        return false;
      }
      debugPrint('❌ Error restoring session: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected error restoring session: $e');
      return false;
    }
  }

  /// Logout the current user
  /// Destroys Appwrite session and clears state
  Future<void> logout() async {
    try {
      // Destroy Appwrite session
      await _appwriteService.account.deleteSession(sessionId: 'current');
      debugPrint('✅ Destroyed Appwrite session');
    } catch (e) {
      debugPrint('⚠️ Error destroying session (may already be logged out): $e');
    }

    // Clear local interview history so the next user doesn't see previous user's data
    try {
      final sharedPrefs = await SharedPreferences.getInstance();
      await sharedPrefs.remove('stored_interviews');
      await sharedPrefs.remove('stored_responses');
      debugPrint('✅ Cleared local interview history on logout');
    } catch (e) {
      debugPrint('⚠️ Failed to clear local interview history on logout: $e');
    }

    // Clear in-memory interview cache to prevent data leakage between users
    try {
      final interviewRepository = sl<InterviewRepository>();
      await interviewRepository.clearAllInterviews();
      debugPrint('✅ Cleared in-memory interview cache on logout');
    } catch (e) {
      debugPrint('⚠️ Failed to clear interview cache on logout: $e');
    }

    // Clear local state and cache regardless of session deletion result
    _authStateProvider.clearAuthState();
    await _clearCache();

    debugPrint('✅ Cleared local authentication state and cache');
  }

  /// Normalize email: trim whitespace and convert to lowercase
  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  /// Normalize auth code: trim whitespace
  String _normalizeAuthCode(String authCode) {
    return authCode.trim();
  }

  /// Save authentication data to secure local cache
  Future<void> _saveToCache(
    String email,
    String companyId,
    String interviewerId,
  ) async {
    await Future.wait([
      _secureStorage.write(key: _emailKey, value: email),
      _secureStorage.write(key: _companyIdKey, value: companyId),
      _secureStorage.write(key: _interviewerIdKey, value: interviewerId),
    ]);
  }

  /// Retrieve authentication data from secure local cache
  Future<Map<String, String?>> _retrieveFromCache() async {
    final results = await Future.wait([
      _secureStorage.read(key: _emailKey),
      _secureStorage.read(key: _companyIdKey),
      _secureStorage.read(key: _interviewerIdKey),
    ]);

    return {
      'email': results[0],
      'companyId': results[1],
      'interviewerId': results[2],
    };
  }

  /// Clear authentication data from secure local cache
  Future<void> _clearCache() async {
    await Future.wait([
      _secureStorage.delete(key: _emailKey),
      _secureStorage.delete(key: _companyIdKey),
      _secureStorage.delete(key: _interviewerIdKey),
    ]);
    // Clear all cached data (roles, questions, etc.) for company isolation
    CacheManager.clear();
  }

  /// Query interviewers collection with normalized email and auth code
  /// Returns InterviewerModel if found, null otherwise
  Future<InterviewerModel?> _queryInterviewersCollection(
    String email,
    String authCode,
  ) async {
    try {
      final response = await _appwriteService.databases.listDocuments(
        databaseId: _appwriteService.databaseId,
        collectionId: _interviewersCollectionId,
        queries: [
          Query.equal('email', email),
          Query.equal('authCode', authCode),
        ],
      );

      if (response.total == 0) {
        return null;
      }

      return InterviewerModel.fromDocument(response.documents.first.data);
    } catch (e) {
      debugPrint('❌ Error querying interviewers collection: $e');
      rethrow;
    }
  }

  /// Handle first-time user login
  /// Creates Appwrite account, session, and updates database
  Future<void> _handleFirstTimeUser(
    String email,
    String appwritePassword,
    InterviewerModel interviewer,
  ) async {
    try {
      // Create Appwrite account
      final user = await _appwriteService.account.create(
        userId: ID.unique(),
        email: email,
        password: appwritePassword,
      );

      debugPrint('✅ Created Appwrite account for first-time user: ${user.$id}');

      // Immediately create session with ghost session cleanup
      await _createSessionWithRetry(email, appwritePassword);

      debugPrint('✅ Created session for first-time user');

      // Update interviewers document with userId
      await _appwriteService.databases.updateDocument(
        databaseId: _appwriteService.databaseId,
        collectionId: _interviewersCollectionId,
        documentId: interviewer.id,
        data: {'userId': user.$id},
      );

      debugPrint('✅ Updated interviewer document with userId');
    } on AppwriteException catch (e) {
      // Handle "User already exists" error gracefully
      if (e.code == 409) {
        debugPrint('⚠️ User already exists, falling back to session creation');
        await _createSessionAndRetryDbUpdate(
          email,
          appwritePassword,
          interviewer.id,
        );
      } else {
        rethrow;
      }
    }
  }

  /// Handle returning user login
  /// Creates session only (account already exists).
  /// If credentials are stale (auth code was rotated), falls back to
  /// first-time user flow which recreates the account with the new password.
  Future<void> _handleReturningUser(
    String email,
    String appwritePassword,
    InterviewerModel interviewer,
  ) async {
    try {
      await _createSessionWithRetry(email, appwritePassword);
      debugPrint('✅ Created session for returning user');
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        // Auth code was rotated — treat as first-time to recreate account
        debugPrint(
          '⚠️ Stale password detected, recreating account with new auth code',
        );
        await _handleFirstTimeUser(email, appwritePassword, interviewer);
      } else {
        rethrow;
      }
    }
  }

  /// Create session with automatic ghost session cleanup and retry
  /// REQUIREMENT 2: Handles session_already_exists errors by cleaning up and retrying
  Future<void> _createSessionWithRetry(
    String email,
    String appwritePassword,
  ) async {
    try {
      await _appwriteService.account.createEmailPasswordSession(
        email: email,
        password: appwritePassword,
      );
    } on AppwriteException catch (e) {
      // ONLY attempt ghost session cleanup for actual session conflict errors
      // Do NOT intercept invalid_credentials or other 401 errors
      final errorMessage = e.message?.toLowerCase() ?? '';
      final isSessionConflict =
          errorMessage.contains('session_already_exists') ||
          errorMessage.contains('user_session_already_exists') ||
          errorMessage.contains('creation of a session is prohibited');

      if (isSessionConflict) {
        debugPrint('⚠️ Ghost session detected, cleaning up and retrying...');

        try {
          // Delete the ghost session
          await _appwriteService.account.deleteSession(sessionId: 'current');
          debugPrint('✅ Deleted ghost session');
        } catch (deleteError) {
          // Silently ignore general_unauthorized_scope errors during cleanup
          if (deleteError is AppwriteException &&
              (deleteError.message?.contains('general_unauthorized_scope') ??
                  false)) {
            debugPrint(
              '⚠️ Ignoring unauthorized scope error during ghost session cleanup',
            );
          } else {
            debugPrint('⚠️ Error deleting ghost session: $deleteError');
          }
        }

        // Retry session creation
        await _appwriteService.account.createEmailPasswordSession(
          email: email,
          password: appwritePassword,
        );
        debugPrint(
          '✅ Successfully created session after ghost session cleanup',
        );
      } else {
        // Not a session conflict - rethrow original error (e.g., invalid_credentials)
        rethrow;
      }
    }
  }

  /// Fallback for "User already exists" error
  /// Creates session and retries database update
  Future<void> _createSessionAndRetryDbUpdate(
    String email,
    String appwritePassword,
    String interviewerId,
  ) async {
    try {
      // Create session with ghost session cleanup
      models.Session? session;
      try {
        session = await _appwriteService.account.createEmailPasswordSession(
          email: email,
          password: appwritePassword,
        );
      } on AppwriteException catch (e) {
        // ONLY attempt ghost session cleanup for actual session conflict errors
        // Do NOT intercept invalid_credentials or other 401 errors
        final errorMessage = e.message?.toLowerCase() ?? '';
        final isSessionConflict =
            errorMessage.contains('session_already_exists') ||
            errorMessage.contains('user_session_already_exists') ||
            errorMessage.contains('creation of a session is prohibited');

        if (isSessionConflict) {
          debugPrint(
            '⚠️ Ghost session detected in fallback, cleaning up and retrying...',
          );

          try {
            // Delete the ghost session
            await _appwriteService.account.deleteSession(sessionId: 'current');
            debugPrint('✅ Deleted ghost session in fallback');
          } catch (deleteError) {
            // Silently ignore general_unauthorized_scope errors during cleanup
            if (deleteError is AppwriteException &&
                (deleteError.message?.contains('general_unauthorized_scope') ??
                    false)) {
              debugPrint(
                '⚠️ Ignoring unauthorized scope error during ghost session cleanup in fallback',
              );
            } else {
              debugPrint(
                '⚠️ Error deleting ghost session in fallback: $deleteError',
              );
            }
          }

          // Retry session creation
          session = await _appwriteService.account.createEmailPasswordSession(
            email: email,
            password: appwritePassword,
          );
          debugPrint(
            '✅ Successfully created session after ghost session cleanup in fallback',
          );
        } else {
          // Not a session conflict - rethrow original error (e.g., invalid_credentials)
          rethrow;
        }
      }

      debugPrint('✅ Created session after "User already exists" error');

      // Retry database update with userId from session
      await _appwriteService.databases.updateDocument(
        databaseId: _appwriteService.databaseId,
        collectionId: _interviewersCollectionId,
        documentId: interviewerId,
        data: {'userId': session.userId},
      );

      debugPrint('✅ Retried database update successfully');
    } catch (e) {
      debugPrint('❌ Error in fallback session creation: $e');
      rethrow;
    }
  }

  /// Handle Appwrite exceptions and map to user-friendly messages
  void _handleAppwriteException(AppwriteException e) {
    if (e.code == 401) {
      // Invalid credentials
      throw Exception("Invalid email or auth code.");
    } else if (e.code == 0 ||
        (e.message?.contains('SocketException') ?? false)) {
      // Network error
      throw Exception(
        "Network error. Please check your connection and try again.",
      );
    } else {
      // Generic error
      throw Exception("Authentication failed. Please try again.");
    }
  }
}
