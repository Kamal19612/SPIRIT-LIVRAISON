import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool    _obscurePassword = true;
  String? _localError;

  static const Color _gray300 = Color(0xFFD1D5DB);
  static const Color _gray500 = Color(0xFF6B7280);
  static const Color _gray700 = Color(0xFF374151);
  static const Color _gray800 = Color(0xFF1F2937);
  static const Color _secondary = Color(0xFF242021);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        _routeByRole(auth);
      }
    });
  }

  void _routeByRole(AuthProvider auth) {
    final route = auth.user!.isAdmin ? '/admin' : '/dashboard';
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _handleLogin() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() => _localError = 'Veuillez remplir tous les champs');
      return;
    }
    setState(() => _localError = null);

    final auth = context.read<AuthProvider>();
    await auth.login(
        _usernameController.text.trim(), _passwordController.text.trim());

    if (!mounted) return;
    if (auth.isAuthenticated) _routeByRole(auth);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final config = context.watch<AppConfigProvider>();
    final primary = config.primaryColor;
    final errorMsg = _localError ?? auth.errorMessage;

    return Scaffold(
      backgroundColor: Color.alphaBlend(primary.withValues(alpha: 0.10), Colors.white),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          offset: const Offset(0, 8),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLogoSection(config),
                        const SizedBox(height: 24),
                        if (errorMsg != null) ...[
                          _buildErrorBlock(errorMsg),
                          const SizedBox(height: 16),
                        ],
                        _buildLabel('Email ou identifiant'),
                        const SizedBox(height: 6),
                        _buildTextField(
                          controller: _usernameController,
                          hint: 'ex. admin (local) ou livreur@sucrestore.com',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Mot de passe'),
                        const SizedBox(height: 6),
                        _buildPasswordField(),
                        const SizedBox(height: 20),
                        _buildSubmitButton(auth.isLoading, primary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection(AppConfigProvider config) {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: config.logoUrl.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: config.logoUrl,
                    fit: BoxFit.cover,
                    errorWidget: (ctx, url, err) => _defaultAvatar(config),
                  ),
                )
              : _defaultAvatar(config),
        ),
        const SizedBox(height: 12),
        Text(
          config.appName.toUpperCase(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _gray800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Connexion',
          style: TextStyle(
            fontSize: 13,
            color: _gray500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar(AppConfigProvider config) => Container(
        decoration: BoxDecoration(
          color: config.primaryColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.local_shipping,
          size: 56,
          color: config.primaryColor,
        ),
      );

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: _gray700),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gray300, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _gray500),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.none,
              style: const TextStyle(fontSize: 15, color: _secondary),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: _gray300),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gray300, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: _gray500),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(fontSize: 15, color: _secondary),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '••••••••',
                hintStyle: TextStyle(color: _gray300),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
              color: _gray500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBlock(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isLoading, Color primary) {
    return Opacity(
      opacity: isLoading ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: isLoading ? null : _handleLogin,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.35),
                offset: const Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : const Text(
                  'Se connecter',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}
