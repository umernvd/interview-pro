import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/presentation/widgets/premium_card.dart';
import '../../../../core/constants/app_colors.dart';

/// Card widget displaying candidate information
class CandidateInfoCard extends StatefulWidget {
  final String candidateName;
  final String? candidateEmail;
  final String role;
  final String level;
  final DateTime interviewDate;
  final String? cvUrl;

  const CandidateInfoCard({
    super.key,
    required this.candidateName,
    this.candidateEmail,
    required this.role,
    required this.level,
    required this.interviewDate,
    this.cvUrl,
  });

  @override
  State<CandidateInfoCard> createState() => _CandidateInfoCardState();
}

class _CandidateInfoCardState extends State<CandidateInfoCard> {
  Future<void> _viewCv(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open CV link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildCandidateInfo(),

          if (widget.candidateEmail != null || widget.cvUrl != null) ...[
            const SizedBox(height: 24),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            _buildCvSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildCandidateInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.candidateName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.role} - ${widget.level}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              _formatDate(widget.interviewDate),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCvSection() {
    if (widget.cvUrl != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () => _viewCv(widget.cvUrl!),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('View CV'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      );
    } else if (widget.candidateEmail != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.email_outlined, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            widget.candidateEmail!,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
