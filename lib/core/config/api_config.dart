import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API Configuration for the Interview Pro App
/// Centralized configuration for all API endpoints
class ApiConfig {
  // Load base URL from .env file, fallback to default if not set
  static String get baseUrl {
    final envUrl = dotenv.get('API_BASE_URL', fallback: '');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    // Fallback to hardcoded URL if .env not configured
    return 'https://harlan-sheaflike-raymond.ngrok-free.dev';
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
