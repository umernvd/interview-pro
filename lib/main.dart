import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'core/services/service_locator.dart';
import 'features/splash/presentation/providers/splash_provider.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';
import 'features/history/presentation/providers/history_provider.dart';
import 'features/interview/presentation/providers/interview_setup_provider.dart';
import 'features/interview/presentation/providers/evaluation_provider.dart';
import 'features/interview/presentation/providers/role_provider.dart';
import 'features/interview/presentation/providers/interview_question_provider.dart';
import 'features/interview/presentation/providers/report_data_provider.dart';
import 'features/interview/presentation/providers/voice_recording_provider.dart';
import 'features/interview/presentation/providers/cv_upload_provider.dart';
import 'core/providers/auth_provider.dart';

import 'dart:async';
import 'core/services/crash_reporting_service.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Load env and run app immediately — don't block on network calls
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        debugPrint('⚠️ .env file not found or failed to load: $e');
      }

      // Initialize crash reporting (fast, local only)
      final crashReporter = CrashReportingService();
      await crashReporter.init();
      FlutterError.onError = crashReporter.handleFlutterError;

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      // Initialize core dependencies synchronously (no network)
      try {
        await initializeDependencies();
        debugPrint('✅ Dependencies initialized successfully');
      } catch (e, stack) {
        debugPrint('⚠️ Failed to initialize dependencies: $e');
        crashReporter.recordError(
          e,
          stack,
          reason: 'Dependency Initialization Failed',
        );
      }

      runApp(const InterviewProApp());
    },
    (error, stack) {
      CrashReportingService().recordError(
        error,
        stack,
        reason: 'Uncaught Global Error',
      );
    },
  );
}

class InterviewProApp extends StatelessWidget {
  const InterviewProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SplashProvider(sl<AuthProvider>()),
        ),
        ChangeNotifierProvider(create: (_) => DashboardProvider(sl())),
        ChangeNotifierProvider(create: (_) => HistoryProvider(sl())),
        ChangeNotifierProvider(
          create: (_) => InterviewSetupProvider(sl(), sl(), sl()),
        ),
        ChangeNotifierProvider(create: (_) => EvaluationProvider(sl())),
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        ChangeNotifierProvider(create: (_) => InterviewQuestionProvider(sl())),
        ChangeNotifierProvider(create: (_) => ReportDataProvider(sl())),
        ChangeNotifierProvider(create: (_) => VoiceRecordingProvider(sl())),
        ChangeNotifierProvider(create: (_) => sl<AuthProvider>()),
        ChangeNotifierProvider(create: (_) => CvUploadProvider(sl())),
      ],
      child: MaterialApp.router(
        title: 'InterviewPro',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
