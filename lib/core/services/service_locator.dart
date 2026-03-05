import 'package:get_it/get_it.dart';
import '../../shared/data/datasources/datasources.dart';
import '../../shared/data/repositories/repositories.dart';
import '../../shared/domain/repositories/interview_repository.dart';
import '../../shared/domain/repositories/role_repository.dart';
import '../../shared/domain/repositories/experience_level_repository.dart';
import '../../shared/domain/repositories/interview_question_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'appwrite_service.dart';
import 'interview_session_manager.dart';
import 'voice_recording_service.dart';
import 'data_management_service.dart';
import 'transcription_service.dart';
import 'drive_service.dart';
import 'upload_queue_service.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state_provider.dart';
import '../../shared/data/datasources/sync_remote_datasource.dart';
import 'auth_service.dart';

/// Service locator for dependency injection
final GetIt sl = GetIt.instance;

/// Initialize all dependencies
Future<void> initializeDependencies() async {
  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('voiceRecordingsBox');
  await UploadQueueService.init();

  // Initialize Appwrite service first
  sl.registerLazySingleton<AppwriteService>(() => AppwriteService.instance);
  sl<AppwriteService>().initialize();
  await sl<AppwriteService>().performSilentLogin();

  // Data sources
  sl.registerLazySingleton<RoleRemoteDatasource>(
    () => RoleRemoteDatasourceImpl(sl<AppwriteService>()),
  );

  sl.registerLazySingleton<ExperienceLevelRemoteDatasource>(
    () => ExperienceLevelRemoteDatasourceImpl(),
  );

  sl.registerLazySingleton<InterviewQuestionRemoteDatasource>(
    () => InterviewQuestionRemoteDatasourceImpl(sl<AppwriteService>()),
  );

  // Repositories
  sl.registerLazySingleton<InterviewRepository>(
    () => InterviewRepositoryImpl(),
  );

  sl.registerLazySingleton<RoleRepository>(
    () => RoleRepositoryImpl(sl<RoleRemoteDatasource>()),
  );

  sl.registerLazySingleton<ExperienceLevelRepository>(
    () => ExperienceLevelRepositoryImpl(),
  );

  sl.registerLazySingleton<InterviewQuestionRepository>(
    () => InterviewQuestionRepositoryImpl(sl()),
  );

  // Services
  sl.registerLazySingleton<DriveService>(
    () => DriveService(), // Client updated dynamically by AuthProvider
  );

  sl.registerLazySingleton<AuthProvider>(
    () => AuthProvider(sl<DriveService>()),
  );

  // Magic Auth Code Login - AuthStateProvider and AuthService
  sl.registerLazySingleton<AuthStateProvider>(() => AuthStateProvider());

  sl.registerLazySingleton<AuthService>(
    () => AuthService(sl<AppwriteService>(), sl<AuthStateProvider>()),
  );

  sl.registerLazySingleton<InterviewSessionManager>(
    () => InterviewSessionManager(sl<InterviewRepository>()),
  );

  sl.registerLazySingleton<VoiceRecordingService>(
    () => VoiceRecordingService(Hive.box('voiceRecordingsBox')),
  );

  sl.registerLazySingleton<UploadQueueService>(
    () => UploadQueueService(
      sl<DriveService>(),
      sl<AuthProvider>(),
      sl<SyncRemoteDatasource>(),
    ),
  );

  sl.registerLazySingleton<DataManagementService>(
    () => DataManagementService(sl<InterviewRepository>()),
  );

  sl.registerLazySingleton<TranscriptionService>(() => TranscriptionService());

  // Sync Service (Sidecar)
  sl.registerLazySingleton<SyncRemoteDatasource>(
    () => SyncRemoteDatasource(sl<AppwriteService>()),
  );

  // Initialize data sources
  // (No local data sources to initialize)

  // Initialize interview questions from JSON
  await sl<InterviewQuestionRepository>().initializeDefaultQuestions();

  // Load any cached interview session
  await sl<InterviewSessionManager>().loadSessionFromCache();
}
