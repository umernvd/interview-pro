import 'package:flutter/material.dart';
import '../../../../shared/domain/entities/entities.dart';
import '../../../../shared/domain/repositories/interview_repository.dart';

/// Provider for managing interview history state
class HistoryProvider extends ChangeNotifier {
  final InterviewRepository _interviewRepository;

  HistoryProvider(this._interviewRepository);

  bool _isLoading = false;
  String? _error;
  int _selectedFilterIndex = 0;
  List<Interview> _allInterviews = [];
  List<Interview> _filteredInterviews = [];

  // Statistics
  int _totalInterviews = 0;
  double _averageScore = 0.0;
  int _hiredCount = 0;

  // Search
  String _searchQuery = '';

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get selectedFilterIndex => _selectedFilterIndex;
  List<Interview> get filteredInterviews => _filteredInterviews;
  int get totalInterviews => _totalInterviews;
  double get averageScore => _averageScore;
  int get hiredCount => _hiredCount;
  String get searchQuery => _searchQuery;

  /// Sets the loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Updates the selected filter index and applies filter
  void updateFilter(int index) {
    _selectedFilterIndex = index;
    _applyFilter();
    notifyListeners();
  }

  /// Searches interviews by candidate name (case-insensitive)
  void searchInterviews(String query) {
    _searchQuery = query.trim();
    _applyFilter();
    notifyListeners();
    debugPrint(
      '🔍 Search: "$_searchQuery" - ${_filteredInterviews.length} results',
    );
  }

  /// Clears the search and shows all filtered interviews
  void clearSearch() {
    _searchQuery = '';
    _applyFilter();
    notifyListeners();
    debugPrint('🔍 Search cleared');
  }

  /// Loads interview history data with enhanced error handling
  Future<void> loadHistoryData() async {
    setLoading(true);
    _error = null;

    try {
      // Load all interviews with timeout
      _allInterviews = await _interviewRepository.getAllInterviews().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout: Unable to load interview history');
        },
      );

      // Calculate statistics
      await _calculateStatistics();

      // Apply current filter
      _applyFilter();

      debugPrint('✅ Loaded ${_allInterviews.length} interviews for history');
    } catch (e) {
      _error = _getErrorMessage(e);
      debugPrint('❌ Error loading history data: $_error');

      // Set fallback data
      _setFallbackData();
    } finally {
      setLoading(false);
    }
  }

  /// Calculate statistics from all interviews with error handling
  Future<void> _calculateStatistics() async {
    try {
      _totalInterviews = _allInterviews.length;

      // Calculate average score from completed interviews with scores
      final completedWithScores = _allInterviews
          .where(
            (interview) =>
                interview.isCompleted &&
                (interview.overallScore != null ||
                    interview.technicalScore >= 0),
          )
          .toList();

      if (completedWithScores.isNotEmpty) {
        final totalScore = completedWithScores
            .map(
              (interview) => interview.overallScore ?? interview.technicalScore,
            )
            .reduce((a, b) => a + b);
        _averageScore = totalScore / completedWithScores.length;
      } else {
        _averageScore = 0.0;
      }

      // Calculate hired count (interviews with score >= 70%)
      _hiredCount = completedWithScores
          .where(
            (interview) =>
                (interview.overallScore ?? interview.technicalScore) >= 70.0,
          )
          .length;

      debugPrint(
        '✅ Statistics calculated: Total=$_totalInterviews, Avg=${_averageScore.toStringAsFixed(1)}, Hired=$_hiredCount',
      );
    } catch (e) {
      debugPrint('❌ Error calculating statistics: $e');
      _totalInterviews = 0;
      _averageScore = 0.0;
      _hiredCount = 0;
    }
  }

  /// Apply filter based on selected index with error handling
  void _applyFilter() {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      switch (_selectedFilterIndex) {
        case 0: // All
          _filteredInterviews = List.from(_allInterviews);
          break;
        case 1: // This Week
          final startOfWeek = startOfToday.subtract(
            Duration(days: now.weekday - 1),
          );
          final endOfWeek = startOfWeek.add(const Duration(days: 7));
          _filteredInterviews = _allInterviews
              .where(
                (interview) =>
                    interview.startTime.isAfter(startOfWeek) &&
                    interview.startTime.isBefore(endOfWeek),
              )
              .toList();
          break;
        case 2: // This Month
          final startOfMonth = DateTime(now.year, now.month, 1);
          final endOfMonth = DateTime(now.year, now.month + 1, 0);
          _filteredInterviews = _allInterviews
              .where(
                (interview) =>
                    interview.startTime.isAfter(startOfMonth) &&
                    interview.startTime.isBefore(endOfMonth),
              )
              .toList();
          break;
        default:
          _filteredInterviews = List.from(_allInterviews);
      }

      // Apply search filter if query is not empty
      if (_searchQuery.isNotEmpty) {
        final lowerQuery = _searchQuery.toLowerCase();
        _filteredInterviews = _filteredInterviews
            .where(
              (interview) =>
                  interview.candidateName.toLowerCase().contains(lowerQuery),
            )
            .toList();
      }

      // Sort by start time (most recent first)
      _filteredInterviews.sort((a, b) => b.startTime.compareTo(a.startTime));

      debugPrint(
        '✅ Filter applied: ${_filteredInterviews.length} interviews shown',
      );
    } catch (e) {
      debugPrint('❌ Error applying filter: $e');
      _filteredInterviews = [];
    }
  }

  /// Set fallback data when loading fails
  void _setFallbackData() {
    _allInterviews = [];
    _filteredInterviews = [];
    _totalInterviews = 0;
    _averageScore = 0.0;
    _hiredCount = 0;
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('timeout')) {
      return 'Connection timeout. Please check your internet connection.';
    } else if (error.toString().contains('network')) {
      return 'Network error. Please try again later.';
    } else if (error.toString().contains('permission')) {
      return 'Permission denied. Please check your access rights.';
    } else {
      return 'Unable to load interview history. Please try again.';
    }
  }

  /// Refreshes the interview history data with retry mechanism
  Future<void> refreshData({int retryCount = 0}) async {
    const maxRetries = 2;

    try {
      await loadHistoryData();
    } catch (e) {
      if (retryCount < maxRetries) {
        debugPrint('Retrying history refresh (${retryCount + 1}/$maxRetries)');
        await Future.delayed(Duration(seconds: (retryCount + 1) * 2));
        return refreshData(retryCount: retryCount + 1);
      } else {
        rethrow;
      }
    }
  }

  /// Clear all interview history and reset statistics
  Future<void> clearAllHistory() async {
    try {
      setLoading(true);
      _interviewRepository.clearAllInterviews();
      _allInterviews = [];
      _filteredInterviews = [];
      _totalInterviews = 0;
      _averageScore = 0.0;
      _hiredCount = 0;

      _applyFilter();
      notifyListeners();
      debugPrint('✅ All interview history cleared');
    } catch (e) {
      debugPrint('❌ Error clearing history: $e');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// Delete an interview and refresh data with error handling
  Future<void> deleteInterview(String interviewId) async {
    try {
      await _interviewRepository.deleteInterview(interviewId);
      await refreshData();
      debugPrint('✅ Interview deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting interview: $e');
      rethrow;
    }
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get filter display name
  String getFilterDisplayName(int index) {
    switch (index) {
      case 0:
        return 'All';
      case 1:
        return 'This Week';
      case 2:
        return 'This Month';
      default:
        return 'All';
    }
  }
}
