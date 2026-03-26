import 'package:flutter/material.dart';
import '../../../../core/config/appwrite_config.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/utils/retry_helper.dart';
import '../../../../core/providers/auth_state_provider.dart';
import '../../../../shared/domain/entities/role.dart';
import '../../../../shared/domain/repositories/role_repository.dart';

/// Provider for managing roles from Appwrite backend
class RoleProvider extends ChangeNotifier {
  final RoleRepository _roleRepository = sl<RoleRepository>();

  List<Role> _roles = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedRoleId;

  // Getters
  List<Role> get roles => _roles;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedRoleId => _selectedRoleId;
  Role? get selectedRole => _selectedRoleId != null
      ? _roles.firstWhere(
          (role) => role.id == _selectedRoleId,
          orElse: () => _roles.first,
        )
      : null;

  /// Load roles from Appwrite backend
  Future<void> loadRoles() async {
    _setLoading(true);
    _error = null;

    // Guard: companyId must be set before we can fetch tenant-isolated roles
    final companyId = sl<AuthStateProvider>().companyId;
    if (companyId == null) {
      _error = 'Not authenticated';
      debugPrint('❌ Cannot load roles: companyId is null');
      _setLoading(false);
      return;
    }

    // Try to get from cache first
    final cachedRoles = CacheManager.get<List<Role>>(CacheManager.rolesKey);
    if (cachedRoles != null && cachedRoles.isNotEmpty) {
      debugPrint('✅ Using cached roles (${cachedRoles.length} items)');
      _roles = cachedRoles;
      _setLoading(false);
      return;
    }

    // Load from backend - no fallback allowed
    if (AppwriteConfig.isConfigured) {
      await _loadFromBackend();
    } else {
      _error = 'Appwrite not configured';
      debugPrint('❌ Appwrite not configured');
    }

    _setLoading(false);
  }

  /// Load roles from backend with proper error handling
  Future<void> _loadFromBackend() async {
    try {
      await RetryHelper.withRetry(
        () async {
          // Fetch roles from backend
          debugPrint('📥 Fetching roles from backend...');
          final backendRoles = await _roleRepository.getRoles();

          if (backendRoles.isNotEmpty) {
            debugPrint(
              '✅ Successfully loaded ${backendRoles.length} roles from backend',
            );
            _roles = backendRoles;
            CacheManager.set(
              CacheManager.rolesKey,
              backendRoles,
              CacheManager.rolesTTL,
            );
            notifyListeners();
          } else {
            _error = 'No roles configured for this company';
            debugPrint('❌ No roles returned from backend');
          }
        },
        config: RetryHelper.networkConfig,
        shouldRetry: RetryHelper.isRetryableError,
      );
    } catch (e) {
      _error = 'Failed to load roles: $e';
      debugPrint('❌ Error loading roles: $e');
      rethrow;
    }
  }

  /// Select a role by ID
  void selectRole(String roleId) {
    if (_roles.any((role) => role.id == roleId) && _selectedRoleId != roleId) {
      _selectedRoleId = roleId;
      notifyListeners();
    }
  }

  /// Clear selected role
  void clearSelection() {
    if (_selectedRoleId != null) {
      _selectedRoleId = null;
      notifyListeners();
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Refresh roles from backend
  Future<void> refreshRoles() async {
    // Clear cache to force fresh data
    CacheManager.remove(CacheManager.rolesKey);
    await loadRoles();
  }

  @override
  void dispose() {
    // Cancel any pending operations
    super.dispose();
  }
}
