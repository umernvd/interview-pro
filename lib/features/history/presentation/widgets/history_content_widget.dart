import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/domain/entities/entities.dart';
import '../providers/history_provider.dart';
import '../../../../shared/presentation/widgets/premium_card.dart';

/// History content widget that displays interview history within the dashboard
class HistoryContentWidget extends StatefulWidget {
  const HistoryContentWidget({super.key});

  @override
  State<HistoryContentWidget> createState() => _HistoryContentWidgetState();
}

class _HistoryContentWidgetState extends State<HistoryContentWidget> {
  @override
  void initState() {
    super.initState();
    // Load history data when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().loadHistoryData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundLight, // Background light color from HTML
      child: Column(
        children: [
          // Filter chips section
          _buildFilterChips(),

          // Stats carousel section
          _buildStatsCarousel(),

          // Interview list section
          Expanded(child: _buildInterviewList()),
        ],
      ),
    );
  }

  /// Builds the filter chips (All, This Week, This Month)
  Widget _buildFilterChips() {
    return Container(
      color: AppColors.backgroundLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Consumer<HistoryProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(3, (index) {
                bool isSelected = provider.selectedFilterIndex == index;
                String option = provider.getFilterDisplayName(index);

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => provider.updateFilter(index),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFF3E8E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF666666),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  /// Builds the stats carousel with Total Interviews, Avg Score, Hired
  Widget _buildStatsCarousel() {
    return Container(
      color: AppColors.backgroundLight,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Consumer<HistoryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatCard(
                  'Total Interviews',
                  provider.totalInterviews.toString(),
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Avg Score',
                  provider.averageScore.toStringAsFixed(1),
                ),
                const SizedBox(width: 16),
                _buildStatCard('Hired', provider.hiredCount.toString()),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds individual stat card
  Widget _buildStatCard(String title, String value) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6D0D2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the scrollable interview list
  Widget _buildInterviewList() {
    return Container(
      color: AppColors.backgroundLight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Consumer<HistoryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          // Show error state with retry option
          if (provider.error != null) {
            return _buildErrorState(provider.error!, () {
              provider.clearError();
              provider.refreshData();
            });
          }

          if (provider.filteredInterviews.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            itemCount: provider.filteredInterviews.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildInterviewListItem(
                  provider.filteredInterviews[index],
                ),
              );
            },
            // Performance optimization: cache extent for smooth scrolling
            cacheExtent: 500.0,
            // Add physics for better scrolling experience
            physics: const BouncingScrollPhysics(),
          );
        },
      ),
    );
  }

  /// Builds empty state when no interviews are found
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No interviews found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start conducting interviews to see them here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds error state with retry option
  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Unable to Load History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.red[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
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

  /// Builds individual interview list item
  Widget _buildInterviewListItem(Interview interview) {
    return GestureDetector(
      onTap: () => _navigateToInterviewReport(interview),
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Left colored indicator based on status
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: _getStatusColor(interview.status),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(width: 12),

            // Interview details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    interview.candidateName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${_getRoleDisplayName(interview)} - ${_getLevelDisplayName(interview.level)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const Text(
                        ' • ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF999999),
                        ),
                      ),
                      Text(
                        _formatDate(interview.startTime),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (interview.overallScore ?? interview.technicalScore) > 0
                    ? AppColors.primary
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                (interview.overallScore ?? interview.technicalScore) > 0
                    ? (interview.overallScore ?? interview.technicalScore)
                          .toStringAsFixed(1)
                    : '--',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color:
                      (interview.overallScore ?? interview.technicalScore) > 0
                      ? Colors.white
                      : const Color(0xFF999999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get status color based on interview status
  Color _getStatusColor(InterviewStatus status) {
    switch (status) {
      case InterviewStatus.completed:
        return AppColors
            .primary; // Changed from success (green) to primary (red)
      case InterviewStatus.inProgress:
        return AppColors.warning;
      case InterviewStatus.cancelled:
        return AppColors.error;
      case InterviewStatus.notStarted:
        return AppColors.grey500;
    }
  }

  /// Get role display name
  String _getRoleDisplayName(Interview interview) {
    // Priority 1: Use the actual roleName string if available
    if (interview.roleName.isNotEmpty) {
      return interview.roleName;
    }

    // Fallback to dynamic role name
    return interview.role.name;
  }

  /// Get level display name
  String _getLevelDisplayName(ExperienceLevel level) {
    return level.title;
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Navigate to interview report
  void _navigateToInterviewReport(Interview interview) {
    try {
      if (interview.candidateName.isEmpty) return;

      final candidateName = Uri.encodeComponent(interview.candidateName);
      final roleValue = Uri.encodeComponent(_getRoleDisplayName(interview));
      final levelValue = Uri.encodeComponent(
        _getLevelDisplayName(interview.level),
      );
      final overallScore = interview.overallScore ?? interview.technicalScore;
      final communicationSkills = interview.softSkillsScore?.round() ?? 3;
      final problemSolvingApproach = interview.technicalScore.round();
      final culturalFit = interview.softSkillsScore?.round() ?? 3;
      final overallImpression = interview.overallScore?.round() ?? 3;
      final additionalComments = Uri.encodeComponent(
        'Generated from interview session',
      );
      final interviewId = interview.id;

      context.push(
        '${AppRouter.interviewReport}?candidateName=$candidateName&role=$roleValue&level=$levelValue&overallScore=$overallScore&communicationSkills=$communicationSkills&problemSolvingApproach=$problemSolvingApproach&culturalFit=$culturalFit&overallImpression=$overallImpression&additionalComments=$additionalComments&interviewId=$interviewId',
      );
    } catch (e) {
      debugPrint('Error navigating to report: $e');
    }
  }
}
