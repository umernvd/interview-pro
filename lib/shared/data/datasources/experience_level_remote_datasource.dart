import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/experience_level.dart';
import '../../../core/services/appwrite_service.dart';
import '../../../core/providers/auth_state_provider.dart';
import '../../../core/config/appwrite_config.dart';

/// Remote datasource for experience levels using direct entities
abstract class ExperienceLevelRemoteDatasource {
  Future<List<ExperienceLevel>> getExperienceLevels();
  Future<List<ExperienceLevel>> getExperienceLevelsByRole(String roleId);
  Future<ExperienceLevel> createExperienceLevel({
    required String title,
    required String description,
    required int sortOrder,
  });
  Future<ExperienceLevel> updateExperienceLevel(
    ExperienceLevel experienceLevel,
  );
  Future<void> deleteExperienceLevel(String id);
  Future<bool> hasExperienceLevels();
}

/// Implementation of experience level remote datasource
class ExperienceLevelRemoteDatasourceImpl
    implements ExperienceLevelRemoteDatasource {
  final AppwriteService _appwriteService;
  final AuthStateProvider _authStateProvider;

  static const String _collectionId = 'experience_levels';

  ExperienceLevelRemoteDatasourceImpl(
    this._appwriteService,
    this._authStateProvider,
  );

  ExperienceLevel _docToEntity(dynamic doc) {
    final data = doc.data as Map<String, dynamic>;
    final now = DateTime.now();
    return ExperienceLevel(
      id: doc.$id as String,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      sortOrder: data['sortOrder'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: data['\$createdAt'] != null
          ? DateTime.tryParse(data['\$createdAt'].toString()) ?? now
          : now,
      updatedAt: data['\$updatedAt'] != null
          ? DateTime.tryParse(data['\$updatedAt'].toString()) ?? now
          : now,
    );
  }

  @override
  Future<List<ExperienceLevel>> getExperienceLevels() async {
    try {
      final companyId = _authStateProvider.companyId;
      if (companyId == null) {
        throw Exception('User not authenticated: companyId is null');
      }
      debugPrint('🔍 Fetching experience levels for companyId: $companyId');

      final response = await _appwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('isActive', true),
          Query.equal('companyId', companyId),
          Query.orderAsc('sortOrder'),
        ],
      );

      debugPrint('🔍 Experience levels found: ${response.documents.length}');
      return response.documents.map(_docToEntity).toList();
    } catch (e) {
      throw Exception('Failed to fetch experience levels: $e');
    }
  }

  @override
  Future<List<ExperienceLevel>> getExperienceLevelsByRole(String roleId) async {
    try {
      final companyId = _authStateProvider.companyId;
      if (companyId == null) {
        throw Exception('User not authenticated: companyId is null');
      }

      final response = await _appwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: _collectionId,
        queries: [
          Query.equal('roleId', roleId),
          Query.equal('isActive', true),
          Query.equal('companyId', companyId),
          Query.orderAsc('sortOrder'),
        ],
      );

      return response.documents.map(_docToEntity).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<ExperienceLevel> createExperienceLevel({
    required String title,
    required String description,
    required int sortOrder,
  }) async {
    final now = DateTime.now();
    return ExperienceLevel(
      id: 'custom_${now.millisecondsSinceEpoch}',
      title: title,
      description: description,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<ExperienceLevel> updateExperienceLevel(
    ExperienceLevel experienceLevel,
  ) async {
    return experienceLevel;
  }

  @override
  Future<void> deleteExperienceLevel(String id) async {}

  @override
  Future<bool> hasExperienceLevels() async {
    return true;
  }
}
