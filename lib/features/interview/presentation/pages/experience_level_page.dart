import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/domain/entities/experience_level.dart';
import '../../../../shared/domain/entities/role.dart';
import '../providers/experience_level_provider.dart';
import '../../../../core/services/service_locator.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../../shared/domain/repositories/experience_level_repository.dart';
import '../providers/cv_upload_provider.dart';
import '../providers/interview_setup_provider.dart';

/// Experience level selection screen with Appwrite backend integration
class ExperienceLevelPage extends StatefulWidget {
  final String selectedRole;
  final String selectedRoleName;

  const ExperienceLevelPage({
    super.key,
    required this.selectedRole,
    required this.selectedRoleName,
  });

  @override
  State<ExperienceLevelPage> createState() => _ExperienceLevelPageState();
}

class _ExperienceLevelPageState extends State<ExperienceLevelPage> {
  int? selectedLevelIndex;
  late ExperienceLevelProvider _experienceLevelProvider;

  @override
  void initState() {
    super.initState();
    _experienceLevelProvider = ExperienceLevelProvider(
      sl<ExperienceLevelRepository>(),
    );
    // Load experience levels in background without blocking UI
    _experienceLevelProvider.loadExperienceLevelsInBackground();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _experienceLevelProvider,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Brightness.dark, // Black icons for light theme
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Scrollable content area
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section
                        _buildHeader(),

                        // Experience Level Cards
                        _buildLevelCards(),

                        // Extra spacing at the bottom to ensure last card is accessible
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Fixed Bottom Button
                _buildBottomButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          const SizedBox(height: 16),

          // Title and Subtitle
          const Text(
            'Select Experience Level',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'For ${widget.selectedRoleName} position',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCards() {
    return Consumer<ExperienceLevelProvider>(
      builder: (context, provider, child) {
        final levels = provider.experienceLevels;

        if (provider.isLoading && levels.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        if (levels.isEmpty) {
          return const Center(
            child: Text(
              'No experience levels available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            children: levels.asMap().entries.map((entry) {
              int index = entry.key;
              ExperienceLevel level = entry.value;
              bool isSelected = selectedLevelIndex == index;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildLevelCard(index, level, isSelected),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildLevelCard(int index, ExperienceLevel level, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedLevelIndex = index;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? null
              : Border(left: BorderSide(color: AppColors.primary, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.15 : 0.04),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level.description,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

            // Right Icon
            if (isSelected)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.check, size: 20, color: Colors.white),
              )
            else
              const Icon(Icons.chevron_right, size: 24, color: Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    final bool hasSelection = selectedLevelIndex != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: hasSelection ? _onContinue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasSelection
                  ? AppColors.primary
                  : Colors.grey[300],
              foregroundColor: hasSelection ? Colors.white : Colors.grey[600],
              elevation: hasSelection ? 8 : 0,
              shadowColor: hasSelection
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onContinue() {
    if (selectedLevelIndex == null) return;

    _showCandidateNameDialog();
  }

  /// Shows a modern, minimal dialog with blurred background for candidate name
  void _showCandidateNameDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.1),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: RepaintBoundary(
            child: AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Candidate Info',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              content: SingleChildScrollView(
                child: Consumer<CvUploadProvider>(
                  builder: (context, cvProvider, child) {
                    final hasCv = cvProvider.cvUrl != null;
                    final isUploading = cvProvider.isUploading;
                    final fileName = hasCv ? 'CV Attached' : 'Upload CV';

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Please enter the name of the candidate to start the session.',
                          style: TextStyle(fontSize: 14, color: Colors.black),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: nameController,
                          autofocus: !hasCv,
                          readOnly: hasCv,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(
                            color: hasCv ? Colors.grey[600] : Colors.black,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Full Name',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: hasCv
                                ? Colors.grey[100]
                                : const Color(0xFFF9FAFB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailController,
                          readOnly: hasCv,
                          textCapitalization: TextCapitalization.none,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            color: hasCv ? Colors.grey[600] : Colors.black,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Email',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: hasCv
                                ? Colors.grey[100]
                                : const Color(0xFFF9FAFB),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Phone Number',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            prefixIcon: Icon(
                              Icons.phone_outlined,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // CV Upload Section
                        Column(
                          children: [
                            GestureDetector(
                              onTap: isUploading
                                  ? null
                                  : () async {
                                      if (hasCv) return;

                                      if (nameController.text.trim().isEmpty ||
                                          emailController.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please enter Name and Email first',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      FilePickerResult? result =
                                          await FilePicker.platform.pickFiles(
                                            type: FileType.custom,
                                            allowedExtensions: [
                                              'pdf',
                                              'doc',
                                              'docx',
                                            ],
                                          );

                                      if (result != null &&
                                          result.files.single.path != null) {
                                        final file = File(
                                          result.files.single.path!,
                                        );
                                        await cvProvider.uploadCv(
                                          file: file,
                                          candidateName: nameController.text
                                              .trim(),
                                          candidateEmail: emailController.text
                                              .trim(),
                                          candidatePhone: phoneController.text
                                              .trim(),
                                        );
                                      }
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: hasCv
                                      ? const Color(0xFFF9FAFB)
                                      : AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                  border: hasCv
                                      ? Border.all(color: AppColors.primary)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      hasCv
                                          ? Icons.check_circle
                                          : Icons.upload_file,
                                      color: hasCv
                                          ? AppColors.primary
                                          : Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      isUploading ? 'Uploading...' : fileName,
                                      style: TextStyle(
                                        color: hasCv
                                            ? AppColors.primary
                                            : Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (isUploading) ...[
                                      const SizedBox(width: 12),
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ] else if (hasCv) ...[
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: () => cvProvider.reset(),
                                        child: const Icon(
                                          Icons.close,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (cvProvider.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  cvProvider.errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    context.read<CvUploadProvider>().reset(); // Reset on cancel
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Consumer<CvUploadProvider>(
                  builder: (context, cvProvider, child) {
                    return ElevatedButton(
                      onPressed: cvProvider.isUploading
                          ? null
                          : () async {
                              if (nameController.text.trim().isNotEmpty) {
                                final candidateName = nameController.text
                                    .trim();
                                final candidateEmail = emailController.text
                                    .trim();
                                final candidatePhone = phoneController.text
                                    .trim();

                                // 1. Drive Folder Validation Gate
                                // Check if we already have a folder from CV upload
                                String? driveFolderId =
                                    cvProvider.uploadedFolderId;

                                // If not, we MUST create one now
                                if (driveFolderId == null) {
                                  try {
                                    final setupProvider = context
                                        .read<InterviewSetupProvider>();

                                    // Show blocking dialog while preparing workspace
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (c) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );

                                    driveFolderId = await setupProvider
                                        .prepareCandidateWorkspace(
                                          candidateName,
                                          candidateEmail: candidateEmail,
                                        );

                                    if (context.mounted) {
                                      Navigator.pop(context); // Pop loading
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      Navigator.pop(context); // Pop loading
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                    return;
                                  }
                                }

                                // Get selected level early for use in error messages
                                final levels =
                                    _experienceLevelProvider.experienceLevels;
                                final selectedLevel =
                                    levels[selectedLevelIndex!];
                                final selectedLevelId = selectedLevel.id;

                                // Check if questions are available for this role/level combination
                                final setupProvider = context
                                    .read<InterviewSetupProvider>();

                                // SET the role and level in the provider BEFORE checking question count
                                await setupProvider.setSelectedRole(
                                  Role(
                                    id: widget.selectedRole,
                                    name: widget.selectedRoleName,
                                    icon: '',
                                    description: '',
                                    createdAt: DateTime.now(),
                                    updatedAt: DateTime.now(),
                                  ),
                                );
                                await setupProvider.setSelectedLevel(
                                  selectedLevel,
                                );

                                final questionCount = await setupProvider
                                    .getQuestionCount();

                                if (questionCount == 0) {
                                  if (context.mounted) {
                                    debugPrint(
                                      '⚠️ No questions available for role: ${widget.selectedRole}, level: $selectedLevelId',
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'No questions available for this role and level combination. Please select a different option or contact your company admin.',
                                        ),
                                        backgroundColor: Colors.orange[700],
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                // Capture values before reset
                                final cvFileId = cvProvider.cvFileId;
                                final cvFileUrl = cvProvider.cvUrl;

                                cvProvider
                                    .reset(); // Reset provider state for next use

                                if (context.mounted) {
                                  Navigator.pop(context);
                                }

                                // Build query parameters
                                final Map<String, dynamic> queryParams = {
                                  'role': widget.selectedRole,
                                  'roleName': widget.selectedRoleName,
                                  'level': selectedLevelId,
                                  'levelName': selectedLevel.title,
                                  'candidateName': candidateName,
                                  'candidateEmail': candidateEmail,
                                  'candidatePhone': candidatePhone,
                                  'driveFolderId': driveFolderId,
                                };

                                if (cvFileId != null) {
                                  queryParams['candidateCvId'] = cvFileId;
                                }
                                if (cvFileUrl != null) {
                                  queryParams['candidateCvUrl'] = cvFileUrl;
                                }

                                final uri = Uri(
                                  path: AppRouter.interviewQuestion,
                                  queryParameters: queryParams,
                                );

                                if (context.mounted) {
                                  context.push(uri.toString());
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Start Interview'),
                    );
                  },
                ),
              ],
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
          ),
        );
      },
    );
  }
}

// Remove the old ExperienceLevel class as we now use the entity
