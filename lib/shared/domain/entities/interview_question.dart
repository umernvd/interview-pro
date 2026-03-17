import 'package:equatable/equatable.dart';

/// Enhanced Interview Question entity for comprehensive question management
class InterviewQuestion extends Equatable {
  /// Unique identifier for the question
  final String id;

  /// The actual question text
  final String question;

  /// Category this question belongs to (technical, behavioral, leadership, role-specific)
  final String category;

  /// Difficulty level (beginner, intermediate, advanced)
  final String difficulty;

  /// Evaluation criteria for scoring
  final List<String> evaluationCriteria;

  /// Role-specific identifier (optional, for role-specific questions)
  final String? roleSpecific;

  /// Experience level this question is suitable for (intern, associate, senior)
  final String? experienceLevel;

  /// When this question was created
  final DateTime createdAt;

  /// When this question was last updated
  final DateTime updatedAt;

  /// Whether this question is active/enabled
  final bool isActive;

  const InterviewQuestion({
    required this.id,
    required this.question,
    required this.category,
    required this.difficulty,
    required this.evaluationCriteria,
    this.roleSpecific,
    this.experienceLevel,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  /// Creates a copy of this question with updated fields
  InterviewQuestion copyWith({
    String? id,
    String? question,
    String? category,
    String? difficulty,
    List<String>? evaluationCriteria,
    String? roleSpecific,
    String? experienceLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return InterviewQuestion(
      id: id ?? this.id,
      question: question ?? this.question,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      evaluationCriteria: evaluationCriteria ?? this.evaluationCriteria,
      roleSpecific: roleSpecific ?? this.roleSpecific,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Checks if this question matches the given difficulty level
  bool matchesDifficulty(String level) {
    return difficulty.toLowerCase() == level.toLowerCase();
  }

  /// Checks if this question is suitable for the given role
  bool isSuitableForRole(String? role) {
    if (role == null) return true;
    if (roleSpecific == null) return true;
    return roleSpecific!.toLowerCase().contains(role.toLowerCase()) ||
        role.toLowerCase().contains(roleSpecific!.toLowerCase());
  }

  /// Checks if this question is suitable for the given experience level
  bool matchesExperienceLevel(String? level) {
    if (level == null) return true;
    if (experienceLevel == null) {
      // Fallback: map difficulty to experience level for backward compatibility
      final mappedLevel = _mapDifficultyToLevel(difficulty);
      return mappedLevel.toLowerCase() == level.toLowerCase();
    }
    return experienceLevel!.toLowerCase() == level.toLowerCase();
  }

  /// Maps difficulty to experience level for backward compatibility
  String _mapDifficultyToLevel(String diff) {
    switch (diff.toLowerCase()) {
      case 'beginner':
        return 'intern';
      case 'intermediate':
        return 'associate';
      case 'advanced':
        return 'senior';
      default:
        return 'associate'; // Default fallback
    }
  }

  /// Checks if this question contains any of the given tags
  bool hasAnyTag(List<String> searchTags) {
    // Since tags are removed, return false for tag-based searches
    return false;
  }

  /// Checks if this question matches the search criteria
  bool matchesSearchCriteria({
    String? categoryFilter,
    String? difficultyFilter,
    String? roleFilter,
    String? experienceLevelFilter,
    List<String>? tagFilters,
  }) {
    if (categoryFilter != null &&
        category.toLowerCase() != categoryFilter.toLowerCase()) {
      return false;
    }

    if (difficultyFilter != null && !matchesDifficulty(difficultyFilter)) {
      return false;
    }

    if (roleFilter != null && !isSuitableForRole(roleFilter)) {
      return false;
    }

    if (experienceLevelFilter != null &&
        !matchesExperienceLevel(experienceLevelFilter)) {
      return false;
    }

    if (tagFilters != null && tagFilters.isNotEmpty && !hasAnyTag(tagFilters)) {
      return false;
    }

    return isActive;
  }

  /// Gets a display-friendly category name
  String get categoryDisplayName {
    switch (category.toLowerCase()) {
      case 'technical':
        return 'Technical Skills';
      case 'behavioral':
        return 'Behavioral & Soft Skills';
      case 'leadership':
        return 'Leadership & Management';
      case 'role-specific':
        return 'Role-Specific Questions';
      default:
        return category;
    }
  }

  /// Gets a display-friendly difficulty name with color coding
  String get difficultyDisplayName {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return 'Beginner';
      case 'intermediate':
        return 'Intermediate';
      case 'advanced':
        return 'Advanced';
      default:
        return difficulty;
    }
  }

  /// Gets difficulty color for UI
  String get difficultyColor {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return '#4CAF50'; // Green
      case 'intermediate':
        return '#FF9800'; // Orange
      case 'advanced':
        return '#F44336'; // Red
      default:
        return '#757575'; // Grey
    }
  }

  /// Converts to JSON for Appwrite storage
  Map<String, dynamic> toJson() {
    return {
      // Note: 'id' is not included here as Appwrite uses $id for document ID
      'question': question,
      'category': category,
      'difficulty': difficulty,
      'evaluationCriteria': evaluationCriteria,
      'roleSpecific': roleSpecific,
      'experienceLevel': experienceLevel,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Converts to JSON including ID field (for testing purposes)
  Map<String, dynamic> toTestJson() {
    return {
      'id': id, // Include id for complete serialization in tests
      'question': question,
      'category': category,
      'difficulty': difficulty,
      'evaluationCriteria': evaluationCriteria,
      'roleSpecific': roleSpecific,
      'experienceLevel': experienceLevel,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Creates from JSON (from Appwrite)
  factory InterviewQuestion.fromJson(Map<String, dynamic> json) {
    return InterviewQuestion(
      id: json[r'$id'] ?? json['id'] ?? '',
      question: json['question'] ?? '',
      category: json['category'] ?? '',
      difficulty: json['difficulty'] ?? '',
      evaluationCriteria: List<String>.from(json['evaluationCriteria'] ?? []),
      roleSpecific: json['roleSpecific'],
      experienceLevel: json['experienceLevel'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      isActive: json['isActive'] ?? true,
    );
  }

  @override
  List<Object?> get props => [
    id,
    question,
    category,
    difficulty,
    evaluationCriteria,
    roleSpecific,
    experienceLevel,
    createdAt,
    updatedAt,
    isActive,
  ];

  @override
  String toString() {
    return 'InterviewQuestion(id: $id, category: $category, difficulty: $difficulty, '
        'question: ${question.length > 50 ? '${question.substring(0, 50)}...' : question})';
  }
}
