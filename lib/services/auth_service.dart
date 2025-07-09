import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const String _tokenKey = 'jwt_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';

  // Default JWT token for demo purposes (replace with actual auth flow)
  static const String defaultToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY4Njg0OWU4NWU4NmQ5NTZhZjQxODdiZSIsImVtYWlsIjoidWJhaWQyNzUxQGdtYWlsLmNvbSIsImlhdCI6MTc1MTk3MjgyNCwiZXhwIjoxNzUyNTc3NjI0fQ.w6qpzfNlnsJZxugwxlb6S5P8VYayfmoRQ2Phc5_Pxa0';

  String? _token;
  String? _userId;
  String? _userEmail;
  bool _isAuthenticated = false;

  String? get token => _token;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  bool get isAuthenticated => _isAuthenticated;

  AuthService() {
    // Initialize with default token immediately
    _token = defaultToken;
    _userId = '6847100ea417b00a20f3f051';
    _userEmail = 'hackyabhay@gmail.com';
    _isAuthenticated = true;
    _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey) ?? defaultToken;
      _userId = prefs.getString(_userIdKey);
      _userEmail = prefs.getString(_userEmailKey);

      if (_token != null) {
        _isAuthenticated = true;
        // Extract user info from default token if not stored
        if (_userId == null || _userEmail == null) {
          _userId = '6847100ea417b00a20f3f051';
          _userEmail = 'hackyabhay@gmail.com';
          await _saveAuthData();
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading auth data: $e');
      // Use default token for demo
      _token = defaultToken;
      _userId = '6847100ea417b00a20f3f051';
      _userEmail = 'hackyabhay@gmail.com';
      _isAuthenticated = true;
      await _saveAuthData();
      notifyListeners();
    }
  }

  Future<void> _saveAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString(_tokenKey, _token!);
      }
      if (_userId != null) {
        await prefs.setString(_userIdKey, _userId!);
      }
      if (_userEmail != null) {
        await prefs.setString(_userEmailKey, _userEmail!);
      }
    } catch (e) {
      debugPrint('Error saving auth data: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      // TODO: Implement actual login API call
      // For now, use default token
      _token = defaultToken;
      _userId = '6847100ea417b00a20f3f051';
      _userEmail = email;
      _isAuthenticated = true;

      await _saveAuthData();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userEmailKey);

      _token = null;
      _userId = null;
      _userEmail = null;
      _isAuthenticated = false;

      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  Future<bool> refreshToken() async {
    try {
      // TODO: Implement token refresh logic
      // For now, just return current status
      return _isAuthenticated;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }

  Map<String, String> getAuthHeaders() {
    return {
      'Authorization': 'Bearer ${_token ?? defaultToken}',
      'Content-Type': 'application/json',
    };
  }
}
