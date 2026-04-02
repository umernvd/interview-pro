import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API Configuration for the Interview Pro App
/// Centralized configuration for all API endpoints
class ApiConfig {
  // Environment-specific URLs
  static const String _debugUrl =
      'https://harlan-sheaflike-raymond.ngrok-free.dev';
  static const String _releaseUrl =
      'https://interview-admin.speedforcehosting.com';
  static const String _profileUrl =
      'https://interview-admin.speedforcehosting.com';

  // Load base URL based on environment (priority: env var > build mode)
  static String get baseUrl {
    // Priority 1: Environment variable (allows override for any mode)
    final envUrl = dotenv.get('API_BASE_URL', fallback: '');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    // Priority 2: Build-mode specific URL
    if (kDebugMode) {
      return _debugUrl;
    } else if (kProfileMode) {
      return _profileUrl;
    } else {
      // kReleaseMode
      return _releaseUrl;
    }
  }

  /// API endpoint for fetching random questions
  static String get randomQuestionsEndpoint => '$baseUrl/api/questions/random';

  /// API endpoint for initializing media uploads
  static String get initUploadEndpoint => '$baseUrl/api/mobile/init-upload';

  /// API endpoint for finalizing media uploads
  static String get finalizeUploadEndpoint =>
      '$baseUrl/api/mobile/finalize-upload';

  /// Get the appropriate base URL based on the environment
  /// This can be extended to support different environments (dev, staging, prod)
  static String getBaseUrl() {
    return baseUrl;
  }

  /// Get the appropriate random questions endpoint
  static String getRandomQuestionsUrl() {
    return randomQuestionsEndpoint;
  }

  /// Get the appropriate init upload endpoint
  static String getInitUploadUrl() {
    return initUploadEndpoint;
  }

  /// Get the appropriate finalize upload endpoint
  static String getFinalizeUploadUrl() {
    return finalizeUploadEndpoint;
  }
}
