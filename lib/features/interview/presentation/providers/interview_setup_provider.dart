import 'package:flutter/foundation.dart';
import '../../../../shared/domain/entities/entities.dart';
import '../../../../shared/domain/repositories/repositories.dart';
import '../../../../core/services/drive_service.dart';
import '../../../../shared/data/datasources/sync_remote_datasource.dart';

/// Provider for managing interview setup state and logic
class InterviewSetupProvider extends ChangeNotifier {
  final InterviewQuestionRepository _questionRepository;
  final InterviewRepository _interviewRepository;
  final DriveService _driveService;
  final SyncRemoteDatasource _syncRemoteDatasource;

  InterviewSetupProvider(
    this._questionRepository,
    this._interviewRepository,
    this._driveService,
    this._syncRemoteDatasource,
  );

  bool _isLoading = false;
  Role? _selectedRole;
  ExperienceLevel? _selectedLevel;
  String _candidateName = '';
  List<InterviewQuestion> _availableQuestions = [];

  // Getters
  bool get isLoading => _isLoading;
  Role? get selectedRole => _selectedRole;
  ExperienceLevel? get selectedLevel => _selectedLevel;
  String get candidateName => _candidateName;
  List<InterviewQuestion> get availableQuestions => _availableQuestions;
  bool get isValid =>
      _selectedRole != null &&
      _selectedLevel != null &&
      _candidateName.trim().isNotEmpty;

  /// Prepares the candidate workspace by checking for existing or creating new folder
  Future<String> prepareCandidateWorkspace(
    String candidateName, {
    String? candidateEmail,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Check connection
      if (_driveService.driveApi == null) {
        throw Exception(
          'Google Drive is not connected. Please connect from Dashboard.',
        );
      }

      // 2. Check for existing folder if email provided (Deduplication)
      if (candidateEmail != null && candidateEmail.isNotEmpty) {
        try {
          final existingCandidate = await _syncRemoteDatasource
              .getCandidateByEmail(candidateEmail);
          if (existingCandidate != null) {
            final existingFolderId = existingCandidate['driveFolderId'];
            if (existingFolderId != null &&
                existingFolderId.toString().isNotEmpty) {
              debugPrint(
                '♻️ Reusing existing Drive Folder ID: $existingFolderId for $candidateEmail',
              );
              return existingFolderId;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error checking existing candidate folder: $e');
          // Fallthrough to create new if check fails
        }
      }

      // 3. Create Unique Folder directly
      final folderId = await _driveService.createUniqueCandidateFolder(
        candidateName,
      );

      if (folderId == null) {
        throw Exception(
          'Failed to create a unique folder on Google Drive. Please check your connection.',
        );
      }

      return folderId;
    } catch (e) {
      debugPrint('Error preparing workspace: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set the selected role and update available questions
  Future<void> setSelectedRole(Role role) async {
    if (_selectedRole == role) return;

    _selectedRole = role;
    notifyListeners();

    if (_selectedLevel != null) {
      await _loadQuestions();
    }
  }

  /// Set the selected level and update available questions
  Future<void> setSelectedLevel(ExperienceLevel level) async {
    if (_selectedLevel == level) return;

    _selectedLevel = level;
    notifyListeners();

    if (_selectedRole != null) {
      await _loadQuestions();
    }
  }

  /// Set the candidate name
  void setCandidateName(String name) {
    _candidateName = name;
    notifyListeners();
  }

  /// Load questions based on selected role and level
  Future<void> _loadQuestions() async {
    if (_selectedRole == null || _selectedLevel == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      print('🎯🎯🎯 SETUP PROVIDER: Calling getRandomQuestions() 🎯🎯🎯');
      // Pass the role and level IDs to the repository using the API
      final allQuestions = await _questionRepository.getRandomQuestions(
        count: 100,
        roleSpecific: _selectedRole!.id,
        experienceLevel: _selectedLevel!.id,
      );
      _availableQuestions = allQuestions;
      print(
        '✅ SETUP PROVIDER SUCCESS: Successfully routed to the Next.js API!',
      );
      debugPrint(
        '✅ Loaded ${_availableQuestions.length} questions for role: ${_selectedRole!.name}, level: ${_selectedLevel!.title}',
      );
    } catch (e) {
      debugPrint('Error loading questions: $e');
      _availableQuestions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get the count of available questions for current selection
  Future<int> getQuestionCount() async {
    if (_selectedRole == null || _selectedLevel == null) return 0;

    try {
      final allQuestions = await _questionRepository.getRandomQuestions(
        count: 100,
        roleSpecific: _selectedRole!.id,
        experienceLevel: _selectedLevel!.id,
      );
      return allQuestions.length;
    } catch (e) {
      debugPrint('Error getting question count: $e');
      return 0;
    }
  }

  /// Create a new interview with current settings
  Future<Interview> createInterview(
    String candidateName, {
    String? candidateCvId,
    String? candidateCvUrl,
    String? driveFolderId,
  }) async {
    if (_selectedRole == null || _selectedLevel == null) {
      throw Exception('Role and level must be selected');
    }

    if (candidateName.trim().isEmpty) {
      throw Exception('Candidate name is required');
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Load questions for the interview using IDs
      final allQuestions = await _questionRepository.getRandomQuestions(
        count: 100,
        roleSpecific: _selectedRole!.id,
        experienceLevel: _selectedLevel!.id,
      );
      final suitableQuestions = allQuestions.where((question) {
        return question.isSuitableForRole(_selectedRole!.name) &&
            question.matchesDifficulty(_selectedLevel!.title);
      }).toList();

      if (suitableQuestions.isEmpty) {
        throw Exception('No questions available for selected role and level');
      }

      // Shuffle questions for variety (questions will be loaded dynamically during interview)
      final shuffledQuestions = List<InterviewQuestion>.from(suitableQuestions);
      shuffledQuestions.shuffle();

      // Create the interview
      final interview = Interview(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        candidateName: candidateName.trim(),
        role: _selectedRole!,
        level: _selectedLevel!,
        startTime: DateTime.now(),
        lastModified: DateTime.now(),
        endTime: null,
        responses: [],
        status: InterviewStatus.notStarted,
        overallScore: null,
        candidateCvId: candidateCvId,
        candidateCvUrl: candidateCvUrl,
        driveFolderId: driveFolderId,
      );

      // Save the interview
      await _interviewRepository.saveInterview(interview);

      return interview;
    } catch (e) {
      debugPrint('Error creating interview: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset the provider state
  void reset() {
    _selectedRole = null;
    _selectedLevel = null;
    _candidateName = '';
    _availableQuestions = [];
    _isLoading = false;
    notifyListeners();
  }

  /// Get questions by category for current role and level
  Future<List<InterviewQuestion>> getQuestionsByCategory(
    String category,
  ) async {
    if (_selectedRole == null || _selectedLevel == null) return [];

    try {
      final allQuestions = await _questionRepository.getRandomQuestions(
        count: 100,
        category: category,
        roleSpecific: _selectedRole!.id,
        experienceLevel: _selectedLevel!.id,
      );
      return allQuestions.where((question) {
        return question.category.toLowerCase() == category.toLowerCase() &&
            question.isSuitableForRole(_selectedRole!.name) &&
            question.matchesDifficulty(_selectedLevel!.title);
      }).toList();
    } catch (e) {
      debugPrint('Error getting questions by category: $e');
      return [];
    }
  }

  /// Preview questions for current selection
  Future<List<InterviewQuestion>> previewQuestions({int limit = 5}) async {
    if (_selectedRole == null || _selectedLevel == null) return [];

    try {
      final allQuestions = await _questionRepository.getRandomQuestions(
        count: limit,
        roleSpecific: _selectedRole!.id,
        experienceLevel: _selectedLevel!.id,
      );
      final suitableQuestions = allQuestions.where((question) {
        return question.isSuitableForRole(_selectedRole!.name) &&
            question.matchesDifficulty(_selectedLevel!.title);
      }).toList();

      if (suitableQuestions.length <= limit) {
        return suitableQuestions;
      }

      return suitableQuestions.take(limit).toList();
    } catch (e) {
      debugPrint('Error previewing questions: $e');
      return [];
    }
  }
}
