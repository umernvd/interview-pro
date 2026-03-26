import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import '../../../core/config/appwrite_config.dart';
import '../../../core/services/appwrite_service.dart';
import '../../../core/providers/auth_state_provider.dart';

/// Abstract remote datasource for Role operations
abstract class RoleRemoteDatasource {
  Future<List<Map<String, dynamic>>> getRolesAsJson();
  Future<Map<String, dynamic>?> getRoleByIdAsJson(String id);
  Future<Map<String, dynamic>> createRoleAsJson(Map<String, dynamic> data);
  Future<Map<String, dynamic>> updateRoleAsJson(
    String id,
    Map<String, dynamic> data,
  );
  Future<void> deleteRole(String id);
  Future<bool> hasRoles();
}

/// Implementation of remote datasource for Role operations using Appwrite
class RoleRemoteDatasourceImpl implements RoleRemoteDatasource {
  final AppwriteService _appwriteService;
  final AuthStateProvider _authStateProvider;

  RoleRemoteDatasourceImpl(this._appwriteService, this._authStateProvider);

  @override
  /// Get all active roles from Appwrite with tenant isolation
  Future<List<Map<String, dynamic>>> getRolesAsJson() async {
    try {
      // Validate auth state for tenant isolation
      final companyId = _authStateProvider.companyId;
      if (companyId == null) {
        throw Exception('User not authenticated: companyId is null');
      }
      debugPrint('🔍 Fetching roles for companyId: $companyId');

      final response = await _appwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.rolesCollectionId,
        queries: [
          Query.equal('isActive', true),
          Query.equal('companyId', companyId), // TENANT ISOLATION
          Query.orderAsc('name'),
        ],
      );

      // CRITICAL: Merge doc.$id into the data map so the entity can extract it
      return response.documents.map((doc) {
        return {
          ...doc.data,
          r'$id': doc.$id, // Explicitly include the Appwrite document ID
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch roles: $e');
    }
  }

  @override
  /// Get role by ID from Appwrite
  Future<Map<String, dynamic>?> getRoleByIdAsJson(String id) async {
    try {
      final response = await _appwriteService.databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.rolesCollectionId,
        documentId: id,
      );

      // CRITICAL: Merge doc.$id into the data map
      return {...response.data, r'$id': response.$id};
    } catch (e) {
      if (e is AppwriteException && e.code == 404) {
        return null;
      }
      throw Exception('Failed to fetch role: $e');
    }
  }

  @override
  /// Create a new role in Appwrite
  Future<Map<String, dynamic>> createRoleAsJson(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _appwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.rolesCollectionId,
        documentId: ID.unique(),
        data: data,
      );

      return response.data;
    } catch (e) {
      throw Exception('Failed to create role: $e');
    }
  }

  @override
  /// Update existing role in Appwrite
  Future<Map<String, dynamic>> updateRoleAsJson(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _appwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.rolesCollectionId,
        documentId: id,
        data: data,
      );

      return response.data;
    } catch (e) {
      throw Exception('Failed to update role: $e');
    }
  }

  @override
  /// Delete role from Appwrite
  Future<void> deleteRole(String id) async {
    try {
      await _appwriteService.databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.rolesCollectionId,
        documentId: id,
      );
    } catch (e) {
      throw Exception('Failed to delete role: $e');
    }
  }

  @override
  /// Check if any roles exist in the collection with tenant isolation
  Future<bool> hasRoles() async {
    try {
      // Validate auth state for tenant isolation
      final companyId = _authStateProvider.companyId;
      if (companyId == null) {
        throw Exception('User not authenticated: companyId is null');
      }

      final response = await _appwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.rolesCollectionId,
        queries: [
          Query.limit(1),
          Query.equal('companyId', companyId), // TENANT ISOLATION
        ],
      );

      return response.documents.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
