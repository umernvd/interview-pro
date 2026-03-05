import 'package:flutter/foundation.dart';

/// Provider to manage authentication state for magic auth code login
/// Stores email, companyId, and interviewerId for authenticated users
class AuthStateProvider extends ChangeNotifier {
  String? _email;
  String? _companyId;
  String? _interviewerId;

  /// Get current authenticated user's email
  String? get email => _email;

  /// Get current authenticated user's company ID
  String? get companyId => _companyId;

  /// Get current authenticated user's interviewer ID
  String? get interviewerId => _interviewerId;

  /// Check if user is authenticated
  bool get isAuthenticated =>
      _email != null && _companyId != null && _interviewerId != null;

  /// Set authentication state after successful login
  void setAuthState(String email, String companyId, String interviewerId) {
    _email = email;
    _companyId = companyId;
    _interviewerId = interviewerId;
    notifyListeners();
  }

  /// Clear authentication state on logout
  void clearAuthState() {
    _email = null;
    _companyId = null;
    _interviewerId = null;
    notifyListeners();
  }
}
