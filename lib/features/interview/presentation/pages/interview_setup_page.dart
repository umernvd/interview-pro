import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../core/theme/app_theme_extensions.dart';
import '../../../../shared/domain/entities/role.dart';
import '../providers/role_provider.dart';

/// Role selection screen with dynamic roles from Appwrite backend
class InterviewSetupPage extends StatefulWidget {
  const InterviewSetupPage({super.key});

  @override
  State<InterviewSetupPage> createState() => _InterviewSetupPageState();
}

class _InterviewSetupPageState extends State<InterviewSetupPage> {
  @override
  void initState() {
    super.initState();
    // Load roles when page initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoleProvider>().loadRoles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Consumer<RoleProvider>(
          builder: (context, roleProvider, child) {
            return Stack(
              children: [
                // Main content
                Column(
                  children: [
                    // Header Section
                    _buildHeader(),

                    // Content Area
                    Expanded(child: _buildContent(roleProvider)),
                  ],
                ),

                // Fixed Bottom Button
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomButton(roleProvider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 20,
        20,
        16,
      ),
      decoration: AppThemeExtensions.glassDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => context.pop(),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 24,
                color: AppColors.primary,
              ),
            ),
          ),

          // Title
          const Expanded(
            child: Text(
              'Select Role',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: -0.8,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Spacer to balance
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildContent(RoleProvider roleProvider) {
    if (roleProvider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading roles...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (roleProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load roles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                roleProvider.error!,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => roleProvider.refreshRoles(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (roleProvider.roles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No roles available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          _buildRoleGrid(roleProvider.roles),
          const SizedBox(
            height: 120,
          ), // Standard bottom spacing for the fixed button area
        ],
      ),
    );
  }

  Widget _buildRoleGrid(List<Role> roles) {
    // Calculate dynamic spacing based on screen height and width
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Adjust grid parameters based on width
    final crossAxisSpacing = screenWidth > 400 ? 16.0 : 12.0;
    final mainAxisSpacing = screenHeight > 650 ? 16.0 : 12.0;

    // Use a more stable aspect ratio calculation that works across all screen sizes
    final aspectRatio = screenHeight < 650 ? 1.0 : 1.1;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childAspectRatio: aspectRatio,
        ),
        itemCount: roles.length,
        itemBuilder: (context, index) {
          return _buildRoleCard(roles[index], index);
        },
      ),
    );
  }

  Widget _buildRoleCard(Role role, int index) {
    final roleProvider = context.watch<RoleProvider>();
    final isSelected = roleProvider.selectedRoleId == role.id;
    final screenHeight = MediaQuery.of(context).size.height;

    // Adjust icon and text sizes based on screen height
    final iconSize = screenHeight > 700 ? 32.0 : 28.0;
    final fontSize = screenHeight > 700 ? 16.0 : 14.0;
    final spacing = screenHeight > 700 ? 12.0 : 8.0;

    // Map icon names to IconData
    final iconData = _getIconData(role.icon);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      tween: Tween(begin: 1.0, end: isSelected ? 1.05 : 1.0),
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        onTap: () {
          roleProvider.selectRole(role.id);
          HapticFeedback.lightImpact(); // ⚡ UX: Physical feedback
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration:
              AppThemeExtensions.premiumCardDecoration(
                color: isSelected ? Colors.white : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(20),
              ).copyWith(
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? AppColors.premiumShadow
                    : AppColors.softShadow,
              ),
          child: Stack(
            children: [
              // Main content - perfectly centered
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        iconData,
                        size: iconSize,
                        color: isSelected ? AppColors.primary : Colors.black87,
                      ),
                      SizedBox(height: spacing),
                      Flexible(
                        child: Text(
                          role.name,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.black,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Selected checkmark badge
              if (isSelected)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton(RoleProvider roleProvider) {
    final isRoleSelected = roleProvider.selectedRoleId != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isRoleSelected ? () => _onContinue(roleProvider) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isRoleSelected
                  ? AppColors.primary
                  : Colors.grey[300],
              foregroundColor: isRoleSelected ? Colors.white : Colors.grey[500],
              elevation: isRoleSelected ? 2 : 0,
              shadowColor: isRoleSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[500],
            ),
            child: Text(
              isRoleSelected ? 'Continue' : 'Select a Role to Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: isRoleSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onContinue(RoleProvider roleProvider) {
    if (roleProvider.selectedRole == null) {
      return;
    }

    final selectedRole = roleProvider.selectedRole!;

    // Navigate to experience level selection with role ID and name
    final encodedRoleName = Uri.encodeComponent(selectedRole.name);
    context.push(
      '${AppRouter.experienceLevel}?role=${selectedRole.id}&roleName=$encodedRoleName',
    );
  }

  /// Map icon string to IconData
  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'flutter':
      case 'smartphone':
        return Icons.smartphone;
      case 'design_services':
        return Icons.design_services;
      case 'business_center':
        return Icons.business_center;
      case 'storage':
      case 'dns':
        return Icons.dns;
      case 'bug_report':
        return Icons.bug_report;
      case 'people':
      case 'groups':
        return Icons.groups;
      default:
        return Icons.work;
    }
  }
}
