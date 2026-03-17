import 'package:equatable/equatable.dart';

/// Question Category entity for organizing interview questions
class QuestionCategoryEntity extends Equatable {
  /// Unique identifier for the category
  final String id;

  /// Category name
  final String name;

  /// Category description
  final String description;

  /// Number of questions in this category
  final int questionCount;

  /// Whether this category is active
  final bool isActive;

  /// When this category was created
  final DateTime createdAt;

  /// When this category was last updated
  final DateTime updatedAt;

  const QuestionCategoryEntity({
    required this.id,
    required this.name,
    required this.description,
    this.questionCount = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy of this category with updated fields
  QuestionCategoryEntity copyWith({
    String? id,
    String? name,
    String? description,
    int? questionCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuestionCategoryEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      questionCount: questionCount ?? this.questionCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts to JSON for Appwrite storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'questionCount': questionCount,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Converts to JSON including all fields (for testing purposes)
  Map<String, dynamic> toTestJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'questionCount': questionCount,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Creates from JSON (from Appwrite)
  factory QuestionCategoryEntity.fromJson(Map<String, dynamic> json) {
    return QuestionCategoryEntity(
      id: json[r'$id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      questionCount: json['questionCount'] ?? 0,
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    questionCount,
    isActive,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() {
    return 'QuestionCategoryEntity(id: $id, name: $name, questionCount: $questionCount)';
  }
}
