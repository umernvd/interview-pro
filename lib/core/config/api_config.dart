/// API Configuration for the Interview Pro App
/// Centralized configuration for all API endpoints
class ApiConfig {
  // Development environment configuration
  // Update these values based on your local development setup

  /// Base URL for the Next.js API server
  /// Using ngrok tunnel for secure local development
  /// ngrok URL: https://harlan-sheaflike-raymond.ngrok-free.dev
  ///
  static const String baseUrl ='https://harlan-sheaflike-raymond.ngrok-free.dev';

  /// API endpoint for fetching random questions
  static const String randomQuestionsEndpoint = '$baseUrl/api/questions/random';

  /// API endpoint for initializing media uploads
  static const String initUploadEndpoint = '$baseUrl/api/mobile/init-upload';

  /// API endpoint for finalizing media uploads
  static const String finalizeUploadEndpoint =
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
