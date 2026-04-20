import 'package:flutter/material.dart';
import '../services/app_config_service.dart';
import '../config/app_config.dart';

class AppConfigProvider extends ChangeNotifier {
  String _appName       = AppConfig.defaultAppName;
  String _logoUrl       = AppConfig.defaultLogoUrl;
  Color  _primaryColor  = const Color(0xFFF5AD41);
  String _contactPhone  = '';
  String _contactEmail  = '';
  String _supportWhatsapp = '';

  String get appName        => _appName;
  String get logoUrl        => _logoUrl;
  Color  get primaryColor   => _primaryColor;
  String get contactPhone   => _contactPhone;
  String get contactEmail   => _contactEmail;
  String get supportWhatsapp => _supportWhatsapp;

  String get primaryColorHex {
    final v = _primaryColor.toARGB32();
    return '#${(v & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<void> init() async {
    final config = await AppConfigService.instance.getAll();
    _appName         = config['app_name']       ?? AppConfig.defaultAppName;
    _logoUrl         = config['app_logo_url']   ?? '';
    _primaryColor    = _parseColor(config['primary_color'] ?? AppConfig.defaultPrimaryColor);
    _contactPhone    = config['contact_phone']    ?? '';
    _contactEmail    = config['contact_email']    ?? '';
    _supportWhatsapp = config['support_whatsapp'] ?? '';
    notifyListeners();
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      if (h.length == 6) {
        return Color(int.parse('FF$h', radix: 16));
      }
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return const Color(0xFFF5AD41);
    }
  }

  Future<void> save({
    required String appName,
    required String logoUrl,
    required String primaryColorHex,
    required String contactPhone,
    required String contactEmail,
    required String supportWhatsapp,
  }) async {
    await AppConfigService.instance.save({
      'app_name':         appName,
      'app_logo_url':     logoUrl,
      'primary_color':    primaryColorHex,
      'contact_phone':    contactPhone,
      'contact_email':    contactEmail,
      'support_whatsapp': supportWhatsapp,
    });
    _appName         = appName;
    _logoUrl         = logoUrl;
    _primaryColor    = _parseColor(primaryColorHex);
    _contactPhone    = contactPhone;
    _contactEmail    = contactEmail;
    _supportWhatsapp = supportWhatsapp;
    notifyListeners();
  }
}
