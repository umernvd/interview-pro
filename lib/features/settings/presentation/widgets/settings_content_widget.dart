import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/utils/app_router.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

/// Settings content widget that displays settings within the dashboard
class SettingsContentWidget extends StatefulWidget {
  const SettingsContentWidget({super.key});

  @override
  State<SettingsContentWidget> createState() => _SettingsContentWidgetState();
}

class _SettingsContentWidgetState extends State<SettingsContentWidget> {
  // Settings state - saves immediately when changed
  bool notificationsEnabled = true;
  bool autoSaveRecordings = true;
  String selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundLight, // Background light color from HTML
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20, // Significantly reduced bottom padding
        ),
        child: Column(
          children: [
            // General Settings Section
            const SizedBox(height: 12),
            _buildGeneralSection(),
            const SizedBox(height: 24),

            // Interview Settings Section
            _buildInterviewSettingsSection(),
            const SizedBox(height: 24),

            // Data Settings Section
            _buildDataSection(),
            const SizedBox(height: 24),

            // About Section
            _buildAboutSection(),

            const SizedBox(height: 32),

            // Logout Button
            _buildLogoutButton(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Builds the general settings section
  Widget _buildGeneralSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'GENERAL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
        ),

        // Settings Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[100]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              // Language Setting
              _buildSettingItem(
                title: 'Language',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedLanguage,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
                onTap: () {
                  _showLanguageDialog();
                },
              ),

              // Divider
              _buildDivider(),

              // Notifications Setting
              _buildSettingItem(
                title: 'Notifications',
                trailing: _buildToggleSwitch(
                  value: notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      notificationsEnabled = value;
                    });
                    // Settings save automatically - no need for save button
                    _saveSettings();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the interview settings section
  Widget _buildInterviewSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'INTERVIEW SETTINGS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
        ),

        // Settings Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[100]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              // Question Sets Setting
              _buildSettingItem(
                title: 'Question Sets',
                trailing: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey[400],
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Managed via web dashboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              // Divider
              _buildDivider(),

              // Auto-save recordings Setting
              _buildSettingItem(
                title: 'Auto-save recordings',
                trailing: _buildToggleSwitch(
                  value: autoSaveRecordings,
                  onChanged: (value) {
                    setState(() {
                      autoSaveRecordings = value;
                    });
                    // Settings save automatically
                    _saveSettings();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the data settings section
  Widget _buildDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'DATA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
        ),

        // Settings Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[100]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              // Export Data Setting
              _buildSettingItem(
                title: 'Export Data',
                trailing: Icon(
                  Icons.download,
                  size: 20,
                  color: Colors.grey[400],
                ),
                onTap: () {
                  _showExportDialog();
                },
              ),

              // Divider
              _buildDivider(),

              // Clear History Setting
              _buildSettingItem(
                title: 'Clear History',
                trailing: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.grey[400],
                ),
                onTap: () {
                  _showClearHistoryDialog();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the about section
  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'ABOUT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
        ),

        // Settings Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[100]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              // Version Setting
              _buildSettingItem(
                title: 'Version',
                trailing: Text(
                  '1.0.0',
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                ),
              ),

              // Divider
              _buildDivider(),

              // Privacy Policy Setting
              _buildSettingItem(
                title: 'Privacy Policy',
                trailing: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey[400],
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              // Divider
              _buildDivider(),

              // Terms of Service Setting
              _buildSettingItem(
                title: 'Terms of Service',
                trailing: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey[400],
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the logout button
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => _handleLogout(),
        icon: const Icon(Icons.logout, size: 20, color: AppColors.primary),
        label: const Text(
          'Log Out',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await sl<AuthService>().logout();
      if (mounted) {
        context.go(AppRouter.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    }
  }

  /// Builds a settings item row
  Widget _buildSettingItem({
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  /// Builds a divider line
  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 16),
      color: const Color(0xFFF3E8E9),
    );
  }

  /// Builds a toggle switch
  Widget _buildToggleSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 51,
        height: 31,
        decoration: BoxDecoration(
          color: value ? AppColors.primary : const Color(0xFFF3E8E9),
          borderRadius: BorderRadius.circular(15.5),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 27,
            height: 27,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Saves settings (automatically when settings change)
  void _saveSettings() {
    // Settings are automatically saved when changed
    // In a real app, this would use SharedPreferences or similar
    debugPrint(
      'Settings saved: notifications=$notificationsEnabled, autoSave=$autoSaveRecordings, language=$selectedLanguage',
    );
  }

  /// Shows language selection dialog
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              leading: Icon(
                selectedLanguage == 'English'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selectedLanguage == 'English'
                    ? AppColors.primary
                    : Colors.grey,
              ),
              onTap: () {
                setState(() {
                  selectedLanguage = 'English';
                });
                _saveSettings();
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Spanish'),
              leading: Icon(
                selectedLanguage == 'Spanish'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selectedLanguage == 'Spanish'
                    ? AppColors.primary
                    : Colors.grey,
              ),
              onTap: () {
                setState(() {
                  selectedLanguage = 'Spanish';
                });
                _saveSettings();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Shows export data dialog
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text(
          'Your interview data will be exported as a CSV file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Export functionality - in a real app this would generate and share a file
              _exportData();
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  /// Shows clear history confirmation dialog
  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to clear all interview history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear history functionality - in a real app this would clear the database
              _clearHistory();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// Export data functionality
  void _exportData() {
    // In a real app, this would generate a CSV/JSON file and share it
  }

  /// Clear history functionality
  Future<void> _clearHistory() async {
    try {
      // Clear history via provider
      await context.read<HistoryProvider>().clearAllHistory();

      // Refresh dashboard statistics as well
      if (mounted) {
        context.read<DashboardProvider>().refresh();
      }

      if (mounted) {
        // History cleared
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
