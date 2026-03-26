import 'package:flutter/foundation.dart';
import '../../../../core/providers/base_provider.dart';
import '../../../../shared/domain/entities/experience_level.dart';
import '../../../../shared/domain/repositories/experience_level_repository.dart';

/// Provider for managing experience level state and operations
class ExperienceLevelProvider extends BaseProvider<ExperienceLevel> {
  final ExperienceLevelRepository _repository;

  ExperienceLevelProvider(this._repository);

  List<ExperienceLevel> get experienceLevels => items;

  /// Default experience levels as fallback
  static const List<Map<String, dynamic>> _defaultLevels = [
    {
      'title': 'Intern',
      'description': '0-1 years experience, basic concepts',
      'sortOrder': 1,
    },
    {
      'title': 'Associate',
      'description': '1-3 years experience, solid fundamentals',
      'sortOrder': 2,
    },
    {
      'title': 'Senior',
      'description': '3+ years experience, advanced expertise',
      'sortOrder': 3,
    },
  ];

  /// Load experience levels with backend integration
  Future<void> loadExperienceLevels() async {
    await loadItemsWithFallback(
      loadFromBackend: _loadFromBackend,
      loadFallback: _loadFallbackLevels,
    );
  }

  /// Load experience levels in background without blocking UI
  void loadExperienceLevelsInBackground() {
    loadExperienceLevels();
  }

  /// Load experience levels from backend
  Future<void> _loadFromBackend() async {
    debugPrint('📥 Fetching experience levels from backend...');
    final levels = await _repository.getExperienceLevels();

    if (levels.isNotEmpty) {
      setItems(levels);
      markBackendTried();
      debugPrint(
        '✅ Successfully loaded ${levels.length} experience levels from backend',
      );
    } else {
      debugPrint('❌ No experience levels returned from backend');
    }
  }

  /// Load fallback experience levels
  void _loadFallbackLevels() {
    debugPrint('🔄 Using fallback experience levels');
    final fallbackLevels = _defaultLevels
        .map(
          (data) => ExperienceLevel(
            id: 'fallback_${data['sortOrder']}',
            title: data['title'],
            description: data['description'],
            sortOrder: data['sortOrder'],
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        )
        .toList();

    setItems(fallbackLevels);
  }

  /// Refresh experience levels from backend
  Future<void> refreshExperienceLevels() async {
    resetBackendTried();
    await loadExperienceLevels();
  }

  /// Create a new experience level
  Future<void> createExperienceLevel({
    required String title,
    required String description,
    required int sortOrder,
  }) async {
    try {
      setLoading(true);
      final newLevel = await _repository.createExperienceLevel(
        title: title,
        description: description,
        sortOrder: sortOrder,
      );

      final updatedLevels = [...items, newLevel];
      updatedLevels.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      setItems(updatedLevels);
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// Update an existing experience level
  Future<void> updateExperienceLevel(ExperienceLevel experienceLevel) async {
    try {
      setLoading(true);
      final updatedLevel = await _repository.updateExperienceLevel(
        experienceLevel,
      );

      final updatedLevels = items
          .map((level) => level.id == updatedLevel.id ? updatedLevel : level)
          .toList();
      updatedLevels.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      setItems(updatedLevels);
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// Delete an experience level
  Future<void> deleteExperienceLevel(String id) async {
    try {
      setLoading(true);
      await _repository.deleteExperienceLevel(id);

      final updatedLevels = items.where((level) => level.id != id).toList();
      setItems(updatedLevels);
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  @override
  void dispose() {
    // Clean up any resources
    super.dispose();
  }
}
