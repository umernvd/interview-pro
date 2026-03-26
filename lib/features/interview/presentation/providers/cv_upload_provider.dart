import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../shared/data/datasources/sync_remote_datasource.dart';

enum CvUploadStatus { idle, checking, selected, error }

/// Manages CV file selection and candidate info.
/// Actual upload happens alongside audio at end of interview via InterviewMediaUploadService.
class CvUploadProvider extends ChangeNotifier {
  final SyncRemoteDatasource _syncRemoteDatasource;

  CvUploadProvider(this._syncRemoteDatasource);

  CvUploadStatus _status = CvUploadStatus.idle;
  File? _cvFile;
  String? _cvUrl; // Set after actual upload completes
  String? _uploadedFolderId;
  String? _errorMessage;

  CvUploadStatus get status => _status;
  File? get cvFile => _cvFile;
  String? get cvUrl => _cvUrl;
  String? get errorMessage => _errorMessage;
  String? get uploadedFolderId => _uploadedFolderId;
  bool get isUploading => false; // No pre-upload anymore
  bool get hasFile => _cvFile != null || _cvUrl != null;

  /// Check if candidate already has a CV from a previous session
  Future<void> checkExistingCv(String email) async {
    if (email.isEmpty) return;

    try {
      final candidateData = await _syncRemoteDatasource.getCandidateByEmail(
        email,
      );
      if (candidateData != null) {
        if (candidateData['cvFileUrl'] != null) {
          _cvUrl = candidateData['cvFileUrl'];
          _status = CvUploadStatus.selected;
        }
        if (candidateData['driveFolderId'] != null) {
          _uploadedFolderId = candidateData['driveFolderId'];
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Error checking existing CV: $e');
    }
  }

  /// Select a CV file locally — no upload yet
  void selectCvFile(File file) {
    _cvFile = file;
    _cvUrl = null;
    _status = CvUploadStatus.selected;
    _errorMessage = null;
    notifyListeners();
    debugPrint('📎 CV file selected: ${file.path}');
  }

  void reset() {
    _status = CvUploadStatus.idle;
    _errorMessage = null;
    _cvFile = null;
    _cvUrl = null;
    _uploadedFolderId = null;
    notifyListeners();
  }
}
