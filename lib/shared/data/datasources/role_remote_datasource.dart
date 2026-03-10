import 'package:appwrite/appwrite.dart';
import '../../../core/config/appwrite_config.dart';
import '../../../core/services/appwrite_service.dart';
import '../../../core/providers/auth_state_provider.dart';
import '../models/role_model.dart';

/// Abstract remote datasource for Role operations
abstract class RoleRemoteDatasource {
  Future<List<RoleModel>> getRoles();
  Future<RoleModel?> getRoleById(String id);
  Future<RoleModel> createRole(RoleModel role);
  Future<RoleModel> updateRole(RoleModel role);
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
  Future<List<RoleModel>> getRoles() async {
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
          Query.equal('isActive', true),
          Query.equal('companyId', companyId), // TENANT ISOLATION
          Query.orderAsc('name'),
        ],
      );

      return response.documents
          .map((doc) => RoleModel.fromDocument(doc.data))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch roles: $e');
    }
  }

  @override
  /// Get role by ID from Appwrite
  Future<RoleModel?> getRoleById(String id) async {
    try {
      final response = await _appwriteService.databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.rolesCollectionId,
        documentId: id,
      );

      return RoleModel.fromDocument(response.data);
    } catch (e) {
      if (e is AppwriteException && e.code == 404) {
        return null;
      }
      throw Exception('Failed to fetch role: $e');
    }
  }

  @override
  /// Create a new role in Appwrite
  Future<RoleModel> createRole(RoleModel role) async {
    try {
      final response = await _appwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.rolesCollectionId,
        documentId: ID.unique(),
        data: role.toDocument(),
      );

      return RoleModel.fromDocument(response.data);
    } catch (e) {
      throw Exception('Failed to create role: $e');
    }
  }

  @override
  /// Update existing role in Appwrite
  Future<RoleModel> updateRole(RoleModel role) async {
    try {
      final response = await _appwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.rolesCollectionId,
        documentId: role.id,
        data: role.toDocument(),
      );

      return RoleModel.fromDocument(response.data);
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
