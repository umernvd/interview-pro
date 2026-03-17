import 'package:flutter/material.dart';
import '../../../../core/config/appwrite_config.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/utils/retry_helper.dart';
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
          // Check if roles exist in backend
          final hasRoles = await _roleRepository.hasRoles();

          if (!hasRoles) {
            debugPrint('📝 No roles found, creating default roles...');
            // Create default roles if none exist
            await _createDefaultRoles();
          }

          // Fetch roles from backend
          debugPrint('📥 Fetching roles from backend...');
          final backendRoles = await _roleRepository.getRoles();

          if (backendRoles.isNotEmpty) {
            debugPrint(
              '✅ Successfully loaded ${backendRoles.length} roles from backend',
            );
            _roles = backendRoles;

            // Cache the roles
            CacheManager.set(
              CacheManager.rolesKey,
              backendRoles,
              CacheManager.rolesTTL,
            );

            notifyListeners(); // Update UI with backend data
          } else {
            _error = 'No roles returned from backend';
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

  /// Create default roles in Appwrite backend
  Future<void> _createDefaultRoles() async {
    final defaultRoles = [
      Role(
        id: '',
        name: 'Flutter Developer',
        icon: 'flutter',
        description: 'Mobile app development with Flutter framework',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Role(
        id: '',
        name: 'UI/UX Designer',
        icon: 'design_services',
        description: 'User interface and experience design',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Role(
        id: '',
        name: 'Product Manager',
        icon: 'business_center',
        description: 'Product strategy and management',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Role(
        id: '',
        name: 'Backend Engineer',
        icon: 'storage',
        description: 'Server-side development and APIs',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Role(
        id: '',
        name: 'QA Engineer',
        icon: 'bug_report',
        description: 'Quality assurance and testing',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Role(
        id: '',
        name: 'HR Specialist',
        icon: 'people',
        description: 'Human resources and talent management',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final role in defaultRoles) {
      try {
        await _roleRepository.createRole(role);
      } catch (e) {
        debugPrint('Failed to create role ${role.name}: $e');
      }
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
