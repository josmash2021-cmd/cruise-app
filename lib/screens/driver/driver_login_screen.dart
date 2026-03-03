import 'package:flutter/material.dart';
import '../../config/page_transitions.dart';
import '../../services/api_service.dart';
import '../../services/user_session.dart';
import 'driver_signup_screen.dart';
import 'driver_home_screen.dart';

/// Driver login screen — email + password for existing drivers.
class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFD4A843);
  static const _goldLight = Color(0xFFF5D990);

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _canLogin = false;
  bool _loading = false;
  String? _errorText;

  late AnimationController _entranceCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_validate);
    _passCtrl.addListener(_validate);

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
        );
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _validate() {
    final ok = _emailCtrl.text.trim().isNotEmpty && _passCtrl.text.isNotEmpty;
    if (ok != _canLogin || _errorText != null) {
      setState(() {
        _canLogin = ok;
        _errorText = null;
      });
    }
  }

  /// Bypass all security / rate-limit checks and go straight to driver home.
  Future<void> _bypassLogin() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      // Offline-first: save a mock dev session without hitting the backend.
      // This lets the Quick Access button work even when the server is down.
      await UserSession.saveUser(
        firstName: 'Driver',
        lastName: 'Dev',
        email: 'dev@cruise.app',
        userId: 1,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = 'Quick access failed: $e';
      });
      return;
    }

    await UserSession.saveMode('driver');
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushAndRemoveUntil(
      slideFromRightRoute(const DriverHomeScreen()),
      (_) => false,
    );
  }

  Future<void> _handleLogin() async {
    if (!_canLogin) return;
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      // Step 1: Validate credentials → get login_token
      final loginRes = await ApiService.login(
        identifier: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final loginToken = loginRes['login_token'] as String;

      // Step 2: Exchange login_token for full JWT (auto-saves token)
      await ApiService.completeLogin(loginToken: loginToken);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = e.message;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = 'Connection error. Check your internet.';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    await UserSession.saveMode('driver');
    if (!mounted) return;

    // Navigate to driver home
    Navigator.of(context).pushAndRemoveUntil(
      slideFromRightRoute(const DriverHomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // ── Top bar ──
            Container(
              padding: EdgeInsets.only(top: pad.top + 8, left: 4, right: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.directions_car_filled_rounded,
                          color: _gold,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Driver',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // ── Heading ──
                        ShaderMask(
                          shaderCallback: (r) => const LinearGradient(
                            colors: [_goldLight, _gold],
                          ).createShader(r),
                          child: const Text(
                            'Welcome back,\nDriver',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to start earning with Cruise',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ── Email field ──
                        _buildField(
                          controller: _emailCtrl,
                          label: 'Email or phone',
                          icon: Icons.person_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 18),

                        // ── Password field ──
                        _buildField(
                          controller: _passCtrl,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.white38,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),

                        if (_errorText != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorText!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              // TODO: forgot password flow
                            },
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: _gold,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ── Login button ──
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _canLogin && !_loading
                                ? _handleLogin
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _canLogin
                                  ? _gold
                                  : Colors.white12,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.white12,
                              disabledForegroundColor: Colors.white24,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: _canLogin ? 4 : 0,
                              shadowColor: _gold.withValues(alpha: 0.4),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text(
                                    'Sign in',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // ── Divider ──
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white12,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white12,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // ── Sign up to drive ──
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                slideFromRightRoute(const DriverSignupScreen()),
                              );
                            },
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 20,
                            ),
                            label: const Text(
                              'Sign up to drive',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _gold,
                              side: BorderSide(
                                color: _gold.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Back to rider ──
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Text.rich(
                              TextSpan(
                                text: 'Looking to ride? ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white54,
                                ),
                                children: const [
                                  TextSpan(
                                    text: 'Switch to rider',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Quick Access (bypass security) ──
                        Center(
                          child: TextButton.icon(
                            onPressed: _bypassLogin,
                            icon: const Icon(Icons.bolt_rounded, size: 18),
                            label: const Text(
                              'Quick Access (Dev)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white38,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      cursorColor: _gold,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white38, fontSize: 15),
        prefixIcon: Icon(icon, color: _gold, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    );
  }
}
