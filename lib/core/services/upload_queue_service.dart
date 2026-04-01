import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/providers/auth_state_provider.dart';
import 'interview_media_upload_service.dart';
import 'service_locator.dart';

/// Service to handle background uploads with offline resilience
class UploadQueueService {
  final Box _queueBox;
  final AuthStateProvider _authStateProvider;

  static const String _boxName = 'uploadQueue';
  bool _isProcessRunning = false;

  UploadQueueService(this._authStateProvider) : _queueBox = Hive.box(_boxName) {
    _initConnectivityListener();
  }

  /// Initialize Hive box for the queue
  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  /// Listen for connectivity changes to retry uploads
  void _initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((results) {
      // connectivity_plus 6.0 returns a List<ConnectivityResult>
      if (results.any((result) => result != ConnectivityResult.none)) {
        debugPrint('🌐 Network restored, processing upload queue...');
        processQueue();
      }
    });
  }

  /// Add a file to the upload queue and trigger processing
  Future<void> addToQueue({
    required String interviewId,
    required String filePath,
    required String candidateName,
    String candidateEmail =
        'unknown@candidate.com', // Placeholder until we have real email collection
    String? candidatePhone,
    String? candidateCvId,
    String? candidateCvUrl,
    String? driveFolderId,
    String? roleId,
    String? roleName,
    String? levelId,
    String? levelName,
  }) async {
    final task = {
      'interviewId': interviewId,
      'filePath': filePath,
      'timestamp': DateTime.now().toIso8601String(),
      'retryCount': 0,
      // Add sidecar data to task to avoid dependence on local repository during background processing
      'candidateName': candidateName,
      'candidateEmail': candidateEmail,
      'candidatePhone': candidatePhone,
      'candidateCvId': candidateCvId,
      'candidateCvUrl': candidateCvUrl,
      'driveFolderId': driveFolderId,
      'companyId': _authStateProvider.companyId,
      'interviewerId': _authStateProvider.interviewerId,
      'roleId': roleId,
      'roleName': roleName,
      'levelId': levelId,
      'levelName': levelName,
      'createdTime': DateTime.now().toIso8601String(),
    };

    await _queueBox.add(task);
    debugPrint('📥 Added upload task for $interviewId to queue');

    // Try to process immediately
    processQueue();
  }

  /// Process pending uploads in the queue
  Future<void> processQueue() async {
    if (_isProcessRunning) return;
    if (_queueBox.isEmpty) return;

    // Check connectivity first
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.every((result) => result == ConnectivityResult.none)) {
      debugPrint('⚠️ No internet connection. Pausing upload queue.');
      return;
    }

    _isProcessRunning = true;

    try {
      final keys = _queueBox.keys.toList();

      for (final key in keys) {
        final task = Map<String, dynamic>.from(_queueBox.get(key));
        final String interviewId = task['interviewId'];
        final String filePath = task['filePath'];
        final String candidateName =
            task['candidateName'] ?? 'Unknown Candidate';
        final String? cvFilePath = task['candidateCvId']; // local CV file path

        debugPrint('🔄 Processing upload for $interviewId...');

        try {
          final file = File(filePath);
          if (!await file.exists()) {
            debugPrint('❌ File not found: $filePath. Removing from queue.');
            await _queueBox.delete(key);
            continue;
          }

          final length = await file.length();
          if (length == 0) {
            debugPrint('⚠️ File is empty: $filePath. Removing from queue.');
            await _queueBox.delete(key);
            continue;
          }

          // Upload via backend (no Google Sign-In required)
          final uploadService = sl<InterviewMediaUploadService>();
          final String? roleId = task['roleId'];
          final String? roleName = task['roleName'];
          final String? levelId = task['levelId'];
          final String? levelName = task['levelName'];
          final String? candidateEmail = task['candidateEmail'];
          final String? candidatePhone = task['candidatePhone'];
          final result = await uploadService.uploadInterviewMedia(
            mediaFilePath: filePath,
            candidateName: candidateName,
            candidateEmail: candidateEmail,
            candidatePhone: candidatePhone,
            cvFilePath: cvFilePath,
            roleId: roleId,
            roleName: roleName,
            levelId: levelId,
            levelName: levelName,
          );

          debugPrint('✅ Upload success. Interview created by backend.');
          if (result['candidateFolderId'] != null) {
            debugPrint(
              '📁 Using real Candidate Folder ID: ${result['candidateFolderId']}',
            );
          }

          // NOTE: Backend's finalize-upload endpoint already creates the interview
          // with all required fields (candidateName, roleId, levelId, etc.)
          // No need to sync metadata again - it would overwrite with incomplete data

          await _queueBox.delete(key);
          debugPrint('✨ Task completed and removed from queue');
        } catch (e) {
          debugPrint('❌ Upload failed for $interviewId: $e');

          // Increment retry count
          int retries = task['retryCount'] ?? 0;
          if (retries >= 5) {
            debugPrint('🚫 Max retries reached. Removing task.');
            await _queueBox.delete(key);
          } else {
            task['retryCount'] = retries + 1;
            await _queueBox.put(key, task);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error processing upload queue: $e');
    } finally {
      _isProcessRunning = false;
    }
  }

  /// Get count of pending uploads
  int get pendingCount => _queueBox.length;
}
