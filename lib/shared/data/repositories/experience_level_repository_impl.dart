import '../../domain/entities/experience_level.dart';
import '../../domain/repositories/experience_level_repository.dart';
import '../datasources/experience_level_remote_datasource.dart';

/// Implementation of experience level repository using Appwrite remote datasource
class ExperienceLevelRepositoryImpl implements ExperienceLevelRepository {
  final ExperienceLevelRemoteDatasource _remoteDatasource;

  ExperienceLevelRepositoryImpl(this._remoteDatasource);

  @override
  Future<List<ExperienceLevel>> getExperienceLevels() async {
    return await _remoteDatasource.getExperienceLevels();
  }

  @override
  Future<ExperienceLevel> createExperienceLevel({
    required String title,
    required String description,
    required int sortOrder,
  }) async {
    return await _remoteDatasource.createExperienceLevel(
      title: title,
      description: description,
      sortOrder: sortOrder,
    );
  }

  @override
  Future<ExperienceLevel> updateExperienceLevel(
    ExperienceLevel experienceLevel,
  ) async {
    return await _remoteDatasource.updateExperienceLevel(experienceLevel);
  }

  @override
  Future<void> deleteExperienceLevel(String id) async {
    await _remoteDatasource.deleteExperienceLevel(id);
  }

  @override
  Future<bool> hasExperienceLevels() async {
    return await _remoteDatasource.hasExperienceLevels();
  }
}
