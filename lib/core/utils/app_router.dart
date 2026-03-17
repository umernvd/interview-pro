import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/interview/presentation/pages/interview_setup_page.dart';
import '../../features/interview/presentation/pages/experience_level_page.dart';
import '../../features/interview/presentation/pages/interview_question_page.dart';
import '../../features/interview/presentation/pages/candidate_evaluation_page.dart';
import '../../features/interview/presentation/pages/interview_report_page.dart';
import '../../features/interview/presentation/pages/report_preview_page.dart';

/// Application routing configuration
class AppRouter {
  // Route paths
  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String interview = '/interview';
  static const String experienceLevel = '/experience-level';
  static const String interviewQuestion = '/interview-question';
  static const String candidateEvaluation = '/candidate-evaluation';
  static const String interviewReport = '/interview-report';
  static const String reportPreview = '/report-preview';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: interview,
        name: 'interview',
        builder: (context, state) => const InterviewSetupPage(),
      ),
      GoRoute(
        path: experienceLevel,
        name: 'experience-level',
        builder: (context, state) {
          final selectedRole = state.uri.queryParameters['role'] ?? '';
          final selectedRoleName =
              state.uri.queryParameters['roleName'] ?? selectedRole;
          return ExperienceLevelPage(
            selectedRole: selectedRole,
            selectedRoleName: selectedRoleName,
          );
        },
      ),
      GoRoute(
        path: interviewQuestion,
        name: 'interview-question',
        builder: (context, state) {
          final selectedRole = state.uri.queryParameters['role'] ?? '';
          final selectedLevel = state.uri.queryParameters['level'] ?? '';
          final candidateName =
              state.uri.queryParameters['candidateName'] ?? '';
          final selectedRoleName =
              state.uri.queryParameters['roleName'] ?? selectedRole;
          final selectedLevelName =
              state.uri.queryParameters['levelName'] ?? selectedLevel;
          return InterviewQuestionPage(
            selectedRole: selectedRole,
            selectedLevel: selectedLevel,
            selectedRoleName: selectedRoleName,
            selectedLevelName: selectedLevelName,
            candidateName: candidateName,
            candidateEmail: state.uri.queryParameters['candidateEmail'],
            candidatePhone: state.uri.queryParameters['candidatePhone'],
            candidateCvId: state.uri.queryParameters['candidateCvId'],
            candidateCvUrl: state.uri.queryParameters['candidateCvUrl'],
            driveFolderId:
                state.uri.queryParameters['driveFolderId'], // 🟢 Added
          );
        },
      ),
      GoRoute(
        path: candidateEvaluation,
        name: 'candidate-evaluation',
        builder: (context, state) {
          final candidateName =
              state.uri.queryParameters['candidateName'] ?? '';
          final role = state.uri.queryParameters['role'] ?? '';
          final level = state.uri.queryParameters['level'] ?? '';
          final interviewId = state.uri.queryParameters['interviewId'] ?? '';
          final candidateEmail =
              state.uri.queryParameters['candidateEmail'] ?? '';
          return CandidateEvaluationPage(
            candidateName: candidateName,
            candidateEmail: candidateEmail,
            role: role,
            level: level,
            interviewId: interviewId,
          );
        },
      ),
      GoRoute(
        path: interviewReport,
        name: 'interview-report',
        builder: (context, state) {
          final candidateName =
              state.uri.queryParameters['candidateName'] ?? '';
          final role = state.uri.queryParameters['role'] ?? '';
          final level = state.uri.queryParameters['level'] ?? '';
          final overallScore =
              double.tryParse(
                state.uri.queryParameters['overallScore'] ?? '0',
              ) ??
              0.0;
          final communicationSkills =
              int.tryParse(
                state.uri.queryParameters['communicationSkills'] ?? '0',
              ) ??
              0;
          final problemSolvingApproach =
              int.tryParse(
                state.uri.queryParameters['problemSolvingApproach'] ?? '0',
              ) ??
              0;
          final culturalFit =
              int.tryParse(state.uri.queryParameters['culturalFit'] ?? '0') ??
              0;
          final overallImpression =
              int.tryParse(
                state.uri.queryParameters['overallImpression'] ?? '0',
              ) ??
              0;
          final additionalComments =
              state.uri.queryParameters['additionalComments'] ?? '';
          final interviewId = state.uri.queryParameters['interviewId'];

          return InterviewReportPage(
            candidateName: candidateName,
            role: role,
            level: level,
            overallScore: overallScore,
            communicationSkills: communicationSkills,
            problemSolvingApproach: problemSolvingApproach,
            culturalFit: culturalFit,
            overallImpression: overallImpression,
            additionalComments: additionalComments,
            interviewId: interviewId,
          );
        },
      ),
      GoRoute(
        path: reportPreview,
        name: 'report-preview',
        builder: (context, state) {
          final interviewId = state.uri.queryParameters['interviewId'];

          return ReportPreviewPage(interviewId: interviewId);
        },
      ),
      //  Add other routes as features are implemented
      //  Add other routes as features are implemented
    ],
    // Handle deep link errors or unknown routes
    onException: (context, state, router) {
      router.go(dashboard);
    },
  );
}
