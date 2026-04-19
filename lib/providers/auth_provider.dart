import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<void> init() async {
    _isInitializing = true;
    final restored = await AuthService.instance.tryRestoreSession();
    if (restored != null) {
      _user = restored;
    }
    _isInitializing = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await AuthService.instance.login(username, password);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await AuthService.instance.logout();
    _user = null;
    _isLoading = false;
    notifyListeners();
  }
}
