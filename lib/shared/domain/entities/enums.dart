/// Enumeration for question categories
enum QuestionCategory {
  programmingFundamentals,
  roleSpecificTechnical,
  modernDevelopmentPractices,
  softSkills;

  /// Gets a display-friendly name for the category
  String get displayName {
    switch (this) {
      case QuestionCategory.programmingFundamentals:
        return 'Programming Fundamentals';
      case QuestionCategory.roleSpecificTechnical:
        return 'Role-Specific Technical';
      case QuestionCategory.modernDevelopmentPractices:
        return 'Modern Development Practices';
      case QuestionCategory.softSkills:
        return 'Soft Skills';
    }
  }

  /// Gets a description of the question category
  String get description {
    switch (this) {
      case QuestionCategory.programmingFundamentals:
        return 'Basic programming concepts, data structures, and algorithms';
      case QuestionCategory.roleSpecificTechnical:
        return 'Technical questions specific to the selected role';
      case QuestionCategory.modernDevelopmentPractices:
        return 'Modern development practices, tools, and methodologies';
      case QuestionCategory.softSkills:
        return 'Communication, teamwork, and problem-solving skills';
    }
  }

  /// Gets a short code for the category
  String get code {
    switch (this) {
      case QuestionCategory.programmingFundamentals:
        return 'PF';
      case QuestionCategory.roleSpecificTechnical:
        return 'RST';
      case QuestionCategory.modernDevelopmentPractices:
        return 'MDP';
      case QuestionCategory.softSkills:
        return 'SS';
    }
  }

  /// Creates a QuestionCategory from a string value
  static QuestionCategory fromString(String value) {
    return QuestionCategory.values.firstWhere(
      (category) => category.name.toLowerCase() == value.toLowerCase(),
      orElse: () => throw ArgumentError('Invalid question category: $value'),
    );
  }
}

/// Enumeration for interview status
enum InterviewStatus {
  notStarted,
  inProgress,
  completed,
  cancelled;

  /// Gets a display-friendly name for the status
  String get displayName {
    switch (this) {
      case InterviewStatus.notStarted:
        return 'Not Started';
      case InterviewStatus.inProgress:
        return 'In Progress';
      case InterviewStatus.completed:
        return 'Completed';
      case InterviewStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Gets a description of the interview status
  String get description {
    switch (this) {
      case InterviewStatus.notStarted:
        return 'Interview has been scheduled but not yet started';
      case InterviewStatus.inProgress:
        return 'Interview is currently active';
      case InterviewStatus.completed:
        return 'Interview has been completed successfully';
      case InterviewStatus.cancelled:
        return 'Interview was cancelled before completion';
    }
  }

  /// Checks if the interview can be started
  bool get canStart => this == InterviewStatus.notStarted;

  /// Checks if the interview can be resumed
  bool get canResume => this == InterviewStatus.inProgress;

  /// Checks if the interview is finished (completed or cancelled)
  bool get isFinished =>
      this == InterviewStatus.completed || this == InterviewStatus.cancelled;

  /// Creates an InterviewStatus from a string value
  static InterviewStatus fromString(String value) {
    return InterviewStatus.values.firstWhere(
      (status) => status.name.toLowerCase() == value.toLowerCase(),
      orElse: () => throw ArgumentError('Invalid interview status: $value'),
    );
  }
}

/// Enumeration for interview verdict
enum InterviewVerdict {
  reject,
  hold,
  nextRound,
  hire;

  /// Gets a display-friendly name for the verdict
  String get displayName {
    switch (this) {
      case InterviewVerdict.reject:
        return 'Reject';
      case InterviewVerdict.hold:
        return 'Hold';
      case InterviewVerdict.nextRound:
        return 'Next Round';
      case InterviewVerdict.hire:
        return 'Hire';
    }
  }

  /// Creates a InterviewVerdict from a string value
  static InterviewVerdict fromString(String value) {
    return InterviewVerdict.values.firstWhere(
      (verdict) => verdict.name.toLowerCase() == value.toLowerCase(),
      orElse: () => throw ArgumentError('Invalid verdict: $value'),
    );
  }
}
