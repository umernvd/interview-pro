import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_state_provider.dart';
import 'appwrite_service.dart';
import '../services/service_locator.dart';
import '../config/api_config.dart';

/// Service for uploading interview media files using Deferred Atomic Upload architecture
/// Supports sequential uploads of audio and optional CV files with atomic finalization
class InterviewMediaUploadService {
  final AuthStateProvider _authStateProvider;

  // Next.js API endpoint for initializing uploads (using centralized config)
  static String get _initUploadEndpoint => ApiConfig.initUploadEndpoint;

  // Next.js API endpoint for finalizing uploads (using centralized config)
  static String get _finalizeUploadEndpoint => ApiConfig.finalizeUploadEndpoint;

  // Upload timeout (5 minutes for large video files)
  static const Duration _uploadTimeout = Duration(minutes: 5);

  InterviewMediaUploadService(this._authStateProvider);

  /// Upload interview media files using Deferred Atomic Upload architecture:
  /// 1. Generate fresh Appwrite JWT for authentication
  /// 2. Upload audio file to Google Drive (init + stream)
  /// 3. Upload optional CV file to Google Drive (init + stream)
  /// 4. Finalize upload with backend using both URLs atomically
  /// Returns the response containing interviewId, driveFileUrl, and candidateFolderId
  Future<Map<String, dynamic>> uploadInterviewMedia({
    required String mediaFilePath,
    required String candidateName,
    String? candidateEmail,
    String? candidatePhone,
    String? cvFilePath,
    String? roleId,
    String? roleName,
    String? levelId,
    String? levelName,
    String? companyId,
    String? candidateId,
    String? interviewerId,
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

      // Validate CV file if provided
      if (cvFilePath != null && cvFilePath.isNotEmpty) {
        final cvFile = File(cvFilePath);
        if (!await cvFile.exists()) {
          throw Exception('CV file does not exist: $cvFilePath');
        }
      }

      // Get company ID from auth state if not provided
      final effectiveCompanyId = companyId ?? _authStateProvider.companyId;
      if (effectiveCompanyId == null) {
        throw Exception('User not authenticated: companyId is null');
      }

      // Get interviewer ID from auth state if not provided
      final effectiveInterviewerId =
          interviewerId ?? _authStateProvider.interviewerId;
      if (effectiveInterviewerId == null) {
        throw Exception('User not authenticated: interviewerId is null');
      }

      debugPrint(
        '🎬 Starting media upload for interviewer: $effectiveInterviewerId',
      );
      debugPrint(
        '📁 Audio File: $mediaFilePath (${await mediaFile.length()} bytes)',
      );
      if (cvFilePath != null) {
        debugPrint(
          '📁 CV File: $cvFilePath (${await File(cvFilePath).length()} bytes)',
        );
      }

      // STEP 0: Generate fresh Appwrite JWT for Zero-Trust security
      debugPrint('🔐 Step 0: Generating Appwrite JWT...');
      final appwriteService = sl<AppwriteService>();
      String jwt;
      try {
        final jwtResponse = await appwriteService.account.createJWT();
        jwt = jwtResponse.jwt;
        debugPrint('✅ JWT generated successfully');
      } catch (e) {
        debugPrint('❌ Failed to generate JWT: $e');
        throw Exception('Failed to generate Appwrite JWT: $e');
      }

      // STEP 1: Upload audio file to Google Drive
      debugPrint('📤 Step 1: Uploading audio file to Google Drive...');
      final audioUploadResult = await _uploadSingleFileToDrive(
        filePath: mediaFilePath,
        fileType: 'audio/mp4',
        fileName: '${candidateName.replaceAll(" ", "_")}_audio.m4a',
        candidateName: candidateName,
        interviewerId: effectiveInterviewerId,
        companyId: effectiveCompanyId,
        roleName: roleName,
        jwt: jwt,
      );
      final finalAudioDriveUrl = audioUploadResult['driveUrl']!;
      final candidateFolderId = audioUploadResult['candidateFolderId'];
      debugPrint('✅ Audio file uploaded: $finalAudioDriveUrl');

      // STEP 2: Upload CV file to Google Drive (if provided)
      String? finalCvDriveUrl;
      if (cvFilePath != null && cvFilePath.isNotEmpty) {
        debugPrint('📤 Step 2: Uploading CV file to Google Drive...');
        final cvUploadResult = await _uploadSingleFileToDrive(
          filePath: cvFilePath,
          fileType: 'application/pdf',
          fileName: '${candidateName.replaceAll(" ", "_")}_cv.pdf',
          candidateName: candidateName,
          interviewerId: effectiveInterviewerId,
          companyId: effectiveCompanyId,
          roleName: roleName,
          jwt: jwt,
        );
        finalCvDriveUrl = cvUploadResult['driveUrl'];
        debugPrint('✅ CV file uploaded: $finalCvDriveUrl');
      }

      // STEP 3: Call finalize-upload endpoint with both URLs atomically
      debugPrint('📤 Step 3: Finalizing upload with backend...');

      // Defensive null-check: Ensure audio URL is valid before finalization
      if (finalAudioDriveUrl.isEmpty) {
        throw Exception(
          'Audio upload succeeded but returned an empty Drive URL. Aborting finalization.',
        );
      }

      // Build the finalize payload with all required fields
      final finalizePayload = {
        'sessionUri': finalAudioDriveUrl,
        if (finalCvDriveUrl?.isNotEmpty ?? false) 'cvUri': finalCvDriveUrl,
        'interviewerId': effectiveInterviewerId,
        'companyId': effectiveCompanyId,
        'candidateName': candidateName,
        if (candidateEmail != null && candidateEmail.isNotEmpty)
          'candidateEmail': candidateEmail,
        if (candidatePhone != null && candidatePhone.isNotEmpty)
          'candidatePhone': candidatePhone,
        if (candidateId != null && candidateId.isNotEmpty)
          'candidateId': candidateId,
        if (roleId != null && roleId.isNotEmpty) 'roleId': roleId,
        if (roleName != null && roleName.isNotEmpty) 'roleName': roleName,
        if (levelId != null && levelId.isNotEmpty) 'levelId': levelId,
        if (levelName != null && levelName.isNotEmpty) 'levelName': levelName,
        'status': 'completed',
      };

      debugPrint('🚀 CREATING INTERVIEW PAYLOAD: $finalizePayload');

      final finalizeResponse = await http
          .post(
            Uri.parse(_finalizeUploadEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
              'Authorization': 'Bearer $jwt',
            },
            body: jsonEncode(finalizePayload),
          )
          .timeout(
            _uploadTimeout,
            onTimeout: () {
              throw Exception(
                'Finalize upload timeout: Request took longer than ${_uploadTimeout.inMinutes} minutes',
              );
            },
          );

      if (finalizeResponse.statusCode != 200) {
        final errorBody = finalizeResponse.body;
        debugPrint(
          '❌ Finalize upload failed (${finalizeResponse.statusCode}): $errorBody',
        );
        throw Exception(
          'Failed to finalize upload: ${finalizeResponse.statusCode} - $errorBody',
        );
      }

      final finalizeData = jsonDecode(finalizeResponse.body);
      final String? backendInterviewId = finalizeData['interviewId'];
      final String? driveFileUrl = finalizeData['driveFileUrl'];

      debugPrint('✅ Upload finalized successfully');
      debugPrint('🆔 Backend Interview ID: $backendInterviewId');
      debugPrint('🔗 Drive File URL: $driveFileUrl');

      // Return complete response with all necessary data
      return {
        'status': 'completed',
        'interviewId': backendInterviewId,
        'driveFileUrl': driveFileUrl,
        'audioUrl': finalAudioDriveUrl,
        'cvUrl': finalCvDriveUrl,
        if (candidateFolderId != null) 'candidateFolderId': candidateFolderId,
      };
    } catch (e) {
      debugPrint('❌ Error uploading interview media: $e');
      throw Exception('Failed to upload interview media: $e');
    }
  }

  /// Helper method to upload a single file to Google Drive
  /// Returns a map with 'driveUrl' and optionally 'candidateFolderId'
  Future<Map<String, String>> _uploadSingleFileToDrive({
    required String filePath,
    required String fileType,
    required String fileName,
    required String candidateName,
    required String interviewerId,
    required String companyId,
    String? roleName,
    required String jwt,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      // Init upload with backend
      debugPrint('  📋 Initializing upload for: $fileName');
      final initResponse = await http
          .post(
            Uri.parse(_initUploadEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
              'Authorization': 'Bearer $jwt',
            },
            body: jsonEncode({
              'candidateName': candidateName,
              'fileName': fileName,
              'fileType': fileType,
              'interviewerId': interviewerId,
              'companyId': companyId,
              if (roleName != null && roleName.isNotEmpty) 'roleName': roleName,
            }),
          )
          .timeout(
            _uploadTimeout,
            onTimeout: () {
              throw Exception(
                'Init upload timeout for $fileName: Request took longer than ${_uploadTimeout.inMinutes} minutes',
              );
            },
          );

      if (initResponse.statusCode != 200) {
        final errorBody = initResponse.body;
        debugPrint(
          '  ❌ Init upload failed (${initResponse.statusCode}): $errorBody',
        );
        throw Exception(
          'Failed to initialize upload for $fileName: ${initResponse.statusCode} - $errorBody',
        );
      }

      final initData = jsonDecode(initResponse.body);
      final String uploadUrl = initData['uploadUrl'];
      final String? candidateFolderId = initData['candidateFolderId'];

      debugPrint('  ✅ Upload URL received for: $fileName');
      if (candidateFolderId != null) {
        debugPrint('  📁 Candidate Folder ID: $candidateFolderId');
      }

      // Stream file to Google Drive
      debugPrint('  📤 Streaming $fileName to Google Drive...');
      final fileLength = await file.length();
      final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
      request.contentLength = fileLength;
      request.headers['Content-Type'] = fileType;

      file.openRead().listen(
        (chunk) => request.sink.add(chunk),
        onDone: () => request.sink.close(),
        onError: (e) {
          debugPrint('  ❌ Error streaming $fileName: $e');
          request.sink.close();
        },
      );

      final uploadResponse = await request.send().timeout(
        _uploadTimeout,
        onTimeout: () {
          throw Exception(
            'Stream upload timeout for $fileName: File upload took longer than ${_uploadTimeout.inMinutes} minutes',
          );
        },
      );

      if (uploadResponse.statusCode != 200 &&
          uploadResponse.statusCode != 201) {
        final errorBody = await uploadResponse.stream.bytesToString();
        debugPrint(
          '  ❌ Stream upload failed (${uploadResponse.statusCode}): $errorBody',
        );
        throw Exception(
          'Stream upload failed for $fileName: ${uploadResponse.statusCode} - $errorBody',
        );
      }

      final responseString = await uploadResponse.stream.bytesToString();
      final driveData = jsonDecode(responseString);
      final String driveFileId = driveData['id'];
      final String finalDriveUrl =
          'https://drive.google.com/file/d/$driveFileId/view';
      debugPrint('  ✅ Google Drive File ID: $driveFileId');

      return {
        'driveUrl': finalDriveUrl,
        if (candidateFolderId != null) 'candidateFolderId': candidateFolderId,
      };
    } catch (e) {
      debugPrint('❌ Error uploading file to Drive: $e');
      rethrow;
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
