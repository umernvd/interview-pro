import '../../domain/entities/role.dart';
import '../../domain/repositories/role_repository.dart';
import '../datasources/role_remote_datasource.dart';

/// Implementation of RoleRepository using Appwrite
class RoleRepositoryImpl implements RoleRepository {
  final RoleRemoteDatasource _remoteDatasource;

  RoleRepositoryImpl(this._remoteDatasource);

  @override
  Future<List<Role>> getRoles() async {
    try {
      final roleDocuments = await _remoteDatasource.getRolesAsJson();
      return roleDocuments.map((doc) => Role.fromJson(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get roles: $e');
    }
  }

  @override
  Future<Role?> getRoleById(String id) async {
    try {
      final roleDocument = await _remoteDatasource.getRoleByIdAsJson(id);
      return roleDocument != null ? Role.fromJson(roleDocument) : null;
    } catch (e) {
      throw Exception('Failed to get role by ID: $e');
    }
  }

  @override
  Future<Role> createRole(Role role) async {
    try {
      final roleDocument = await _remoteDatasource.createRoleAsJson({
        'name': role.name,
        'icon': role.icon,
        'description': role.description,
        'isActive': role.isActive,
      });
      return Role.fromJson(roleDocument);
    } catch (e) {
      throw Exception('Failed to create role: $e');
    }
  }

  @override
  Future<Role> updateRole(Role role) async {
    try {
      final roleDocument = await _remoteDatasource.updateRoleAsJson(role.id, {
        'name': role.name,
        'icon': role.icon,
        'description': role.description,
        'isActive': role.isActive,
      });
      return Role.fromJson(roleDocument);
    } catch (e) {
      throw Exception('Failed to update role: $e');
    }
  }

  @override
  Future<void> deleteRole(String id) async {
    try {
      await _remoteDatasource.deleteRole(id);
    } catch (e) {
      throw Exception('Failed to delete role: $e');
    }
  }

  @override
  Future<bool> hasRoles() async {
    try {
      return await _remoteDatasource.hasRoles();
    } catch (e) {
      return false;
    }
  }
}
