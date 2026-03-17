import 'package:equatable/equatable.dart';

/// Role entity for domain layer
class Role extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Role({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory constructor to parse Appwrite document data
  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json[r'$id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      description: json['description'] ?? '',
      isActive: json['isActive'] ?? true,
      createdAt: json[r'$createdAt'] != null
          ? DateTime.parse(json[r'$createdAt'] as String)
          : DateTime.now(),
      updatedAt: json[r'$updatedAt'] != null
          ? DateTime.parse(json[r'$updatedAt'] as String)
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Role && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Role(id: $id, name: $name, icon: $icon, description: $description)';

  @override
  List<Object?> get props => [
    id,
    name,
    icon,
    description,
    isActive,
    createdAt,
    updatedAt,
  ];
}
