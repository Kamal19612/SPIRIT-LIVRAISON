import 'package:flutter/foundation.dart';
import '../models/backend_login_status.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _errorMessage;
  BackendLoginStatus? _backendLoginStatus;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  BackendLoginStatus? get backendLoginStatus => _backendLoginStatus;

  Future<void> init() async {
    _isInitializing = true;
    final restored = await AuthService.instance.tryRestoreSession();
    if (restored != null) {
      _user = restored;
      try {
        await FcmService.instance.registerIfPossible(this);
      } catch (_) {}
    }
    _isInitializing = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _backendLoginStatus = null;
    notifyListeners();

    try {
      final result = await AuthService.instance.login(username, password);
      _user = result.user;
      final status = result.backendStatus;
      if (status.summaryMessage.isNotEmpty) {
        _backendLoginStatus = status;
      }
      try {
        await FcmService.instance.registerIfPossible(this);
      } catch (_) {}
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _user = null;
      _backendLoginStatus = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearBackendLoginStatus() {
    if (_backendLoginStatus == null) return;
    _backendLoginStatus = null;
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await AuthService.instance.logout();
    _user = null;
    _backendLoginStatus = null;
    _isLoading = false;
    notifyListeners();
  }
}
