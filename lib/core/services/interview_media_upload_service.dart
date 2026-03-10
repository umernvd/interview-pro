import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_state_provider.dart';

/// Service for uploading interview media files to Next.js backend
/// Handles multipart/form-data requests with proper error handling
class InterviewMediaUploadService {
  final AuthStateProvider _authStateProvider;

  // Next.js API endpoint for interview uploads
  static const String _uploadEndpoint =
      'https://harlan-sheaflike-raymond.ngrok-free.dev/api/interviews/upload';

  // Upload timeout (5 minutes for large video files)
  static const Duration _uploadTimeout = Duration(minutes: 5);

  InterviewMediaUploadService(this._authStateProvider);

  /// Upload interview media file to Next.js backend
  /// Returns the response containing interviewId and driveFileUrl
  /// Note: Backend generates interviewId, mobile app sends interviewerId
  Future<Map<String, dynamic>> uploadInterviewMedia({
    required String mediaFilePath,
    required String candidateName,
    String? roleName,
    String? companyId,
    void Function(int, int)? onProgress,
  }) async {
    try {
      // Validate inputs
      if (mediaFilePath.isEmpty) {
        throw Exception('Media file path cannot be empty');
      }

      final mediaFile = File(mediaFilePath);
      if (!await mediaFile.exists()) {
        throw Exception('Media file does not exist: $mediaFilePath');
      }

      // Get company ID from auth state if not provided
      final effectiveCompanyId = companyId ?? _authStateProvider.companyId;
      if (effectiveCompanyId == null) {
        throw Exception('User not authenticated: companyId is null');
      }

      // Get interviewer ID from auth state
      final interviewerId = _authStateProvider.interviewerId;
      if (interviewerId == null) {
        throw Exception('User not authenticated: interviewerId is null');
      }

      debugPrint('🎬 Starting media upload for interviewer: $interviewerId');
      debugPrint('📁 File: $mediaFilePath (${await mediaFile.length()} bytes)');

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_uploadEndpoint));

      // Add ngrok bypass header
      request.headers['ngrok-skip-browser-warning'] = 'true';

      // Add form fields (backend generates interviewId)
      request.fields['interviewerId'] = interviewerId;
      request.fields['candidateName'] = candidateName;
      request.fields['companyId'] = effectiveCompanyId;
      if (roleName != null && roleName.isNotEmpty) {
        request.fields['roleName'] = roleName;
      }

      // Add file
      final fileStream = http.ByteStream(mediaFile.openRead());
      final fileLength = await mediaFile.length();
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: 'interview_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      request.files.add(multipartFile);

      debugPrint('📤 Sending multipart request to: $_uploadEndpoint');

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        _uploadTimeout,
        onTimeout: () {
          throw Exception(
            'Upload timeout: File upload took longer than ${_uploadTimeout.inMinutes} minutes',
          );
        },
      );

      // Convert to regular response
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 Upload response status: ${response.statusCode}');

      // Handle response
      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);

        debugPrint('✅ Media upload successful');
        debugPrint(
          '🆔 Interview ID (from backend): ${jsonResponse['interviewId']}',
        );
        debugPrint('🔗 Drive File URL: ${jsonResponse['driveFileUrl']}');

        return jsonResponse as Map<String, dynamic>;
      } else {
        final errorBody = response.body;
        debugPrint('❌ Upload failed (${response.statusCode}): $errorBody');

        throw Exception('Upload failed: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      debugPrint('❌ Error uploading interview media: $e');
      throw Exception('Failed to upload interview media: $e');
    }
  }

  /// Check if a file exists and is readable
  Future<bool> validateMediaFile(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      debugPrint('⚠️ Error validating media file: $e');
      return false;
    }
  }

  /// Get file size in MB
  Future<double> getFileSizeInMB(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.length();
      return bytes / (1024 * 1024);
    } catch (e) {
      debugPrint('⚠️ Error getting file size: $e');
      return 0.0;
    }
  }
}
