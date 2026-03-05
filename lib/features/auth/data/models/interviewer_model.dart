/// Model representing an interviewer document from Appwrite
class InterviewerModel {
  final String id; // $id from Appwrite
  final String email; // Normalized (lowercase, trimmed)
  final String authCode; // 6-digit code (trimmed)
  final String? userId; // Appwrite Account user ID (null for first-time)
  final String companyId; // Organization identifier
  final DateTime createdAt; // Document creation timestamp
  final DateTime updatedAt; // Last update timestamp

  InterviewerModel({
    required this.id,
    required this.email,
    required this.authCode,
    this.userId,
    required this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create InterviewerModel from Appwrite document
  factory InterviewerModel.fromDocument(Map<String, dynamic> document) {
    return InterviewerModel(
      id: document['\$id'] as String,
      email: document['email'] as String,
      authCode: document['authCode'] as String,
      userId: document['userId'] as String?,
      companyId: document['companyId'] as String,
      createdAt: DateTime.parse(document['\$createdAt'] as String),
      updatedAt: DateTime.parse(document['\$updatedAt'] as String),
    );
  }

  /// Convert InterviewerModel to map for Appwrite updates
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'authCode': authCode,
      'userId': userId,
      'companyId': companyId,
    };
  }
}
