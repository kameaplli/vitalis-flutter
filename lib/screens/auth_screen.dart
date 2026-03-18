import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/secure_storage.dart';
import '../services/biometric_service.dart';

// ── Brand colors (app icon: pink → orange → purple gradient) ─────────────────
const _kPink = Color(0xFFE91E63);
const _kPinkDark = Color(0xFF880E4F);
const _kOrange = Color(0xFFFF6D00);
const _kPurple = Color(0xFF7B1FA2);

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _orbCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _regName = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();

  bool _obscureLogin = true;
  bool _obscureReg = true;

  // Biometric state
  bool _showBiometricLogin = false;
  bool _bioLoading = false;
  String? _bioUserName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Floating orbs — perpetual
    _orbCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();

    // Entry animation
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.1, 0.7, curve: Curves.easeOut)));
    _entryCtrl.forward();

    _checkBiometrics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orbCtrl.dispose();
    _entryCtrl.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _regName.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    super.dispose();
  }

  // ── Biometrics ─────────────────────────────────────────────────────────────

  Future<void> _checkBiometrics() async {
    final enabled = await SecureStorage.getBiometricsEnabled();
    final available = await BiometricService.isAvailable();
    if (!enabled || !available) return;
    final creds = await SecureStorage.getBioCredentials();
    if (creds.email == null || creds.password == null) {
      await SecureStorage.setBiometricsPrompted(false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _showBiometricLogin = true;
      _bioUserName = creds.name;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && _showBiometricLogin) _triggerBiometric();
    });
  }

  Future<void> _triggerBiometric() async {
    if (_bioLoading) return;
    setState(() => _bioLoading = true);
    try {
      final ok = await BiometricService.authenticate(reason: 'Sign in to Qorhealth');
      if (!ok) {
        if (mounted) {
          setState(() => _bioLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication failed or was cancelled'), duration: Duration(seconds: 3)),
          );
        }
        return;
      }
      final creds = await SecureStorage.getBioCredentials();
      if (creds.email == null || creds.password == null) {
        if (mounted) setState(() { _showBiometricLogin = false; _bioLoading = false; });
        return;
      }
      final loginOk = await ref.read(authProvider.notifier).login(creds.email!, creds.password!);
      if (!mounted) return;
      if (!loginOk) {
        final err = ref.read(authProvider).error ?? '';
        final is401 = err.toLowerCase().contains('invalid') ||
                      err.toLowerCase().contains('incorrect') ||
                      err.toLowerCase().contains('credential') ||
                      err.toLowerCase().contains('password');
        if (is401) {
          await SecureStorage.clearBioCredentials();
          if (!mounted) return;
          setState(() { _showBiometricLogin = false; _bioLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric login failed — please sign in with your password')),
          );
        } else {
          if (!mounted) return;
          setState(() => _bioLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connection error — check your connection and try again')),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _bioLoading = false);
    }
  }

  // ── Auth actions ───────────────────────────────────────────────────────────

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
      _loginEmail.text.trim(), _loginPassword.text,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Login failed')));
    }
  }

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).register(
      _regName.text.trim(), _regEmail.text.trim(), _regPassword.text,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Registration failed')));
    }
  }

  void _showForgotPasswordSheet(BuildContext context) {
    final emailCtrl = TextEditingController(text: _loginEmail.text.trim());
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reset Password', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Enter your email and we\'ll send you a password reset link.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v?.isEmpty ?? true) ? 'Email required' : null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    try {
                      await apiClient.dio.post(ApiConstants.forgotPassword, data: {'email': emailCtrl.text.trim()});
                    } catch (_) {}
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('If that email exists, a reset link has been sent.')),
                      );
                    }
                  },
                  child: const Text('Send Reset Link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_showBiometricLogin) {
      return _BiometricLoginView(
        userName: _bioUserName,
        loading: _bioLoading,
        onBiometric: _triggerBiometric,
        onUsePassword: () => setState(() => _showBiometricLogin = false),
        orbCtrl: _orbCtrl,
      );
    }

    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kPinkDark, _kPink, _kOrange],
              ),
            ),
          ),

          // Floating orbs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _orbCtrl,
              builder: (_, __) => CustomPaint(painter: _OrbsPainter(_orbCtrl.value)),
            ),
          ),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Column(
                  children: [
                    const SizedBox(height: 36),
                    // Logo
                    _AnimatedLogo(orbCtrl: _orbCtrl),
                    const SizedBox(height: 12),
                    const Text('Qorhealth',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text('Health & Nutrition Tracker',
                        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w300)),
                    const SizedBox(height: 28),

                    // Glass card with forms
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              // Tab bar
                              Theme(
                                data: Theme.of(context).copyWith(
                                  tabBarTheme: TabBarThemeData(
                                    labelColor: Colors.white,
                                    unselectedLabelColor: Colors.white54,
                                    indicatorColor: Colors.white,
                                    dividerColor: Colors.transparent,
                                  ),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  tabs: const [Tab(text: 'Sign In'), Tab(text: 'Register')],
                                  indicatorSize: TabBarIndicatorSize.label,
                                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Forms
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _buildLoginForm(isLoading),
                                    _buildRegisterForm(isLoading),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          children: [
            _glassField(
              controller: _loginEmail,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v?.isEmpty ?? true) ? 'Email required' : null,
            ),
            const SizedBox(height: 14),
            _glassField(
              controller: _loginPassword,
              label: 'Password',
              icon: Icons.lock_outline,
              obscure: _obscureLogin,
              suffixIcon: IconButton(
                icon: Icon(_obscureLogin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.white70, size: 20),
                tooltip: _obscureLogin ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscureLogin = !_obscureLogin),
              ),
              validator: (v) => (v?.isEmpty ?? true) ? 'Password required' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showForgotPasswordSheet(context),
                child: Text('Forgot Password?', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
              ),
            ),
            const SizedBox(height: 8),
            _glassButton(
              onPressed: isLoading ? null : _login,
              isLoading: isLoading,
              label: 'Sign In',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          children: [
            _glassField(
              controller: _regName,
              label: 'Full Name',
              icon: Icons.person_outline,
              validator: (v) => (v?.isEmpty ?? true) ? 'Name required' : null,
            ),
            const SizedBox(height: 14),
            _glassField(
              controller: _regEmail,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v?.isEmpty ?? true) ? 'Email required' : null,
            ),
            const SizedBox(height: 14),
            _glassField(
              controller: _regPassword,
              label: 'Password',
              icon: Icons.lock_outline,
              obscure: _obscureReg,
              suffixIcon: IconButton(
                icon: Icon(_obscureReg ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.white70, size: 20),
                tooltip: _obscureReg ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscureReg = !_obscureReg),
              ),
              validator: (v) => (v?.length ?? 0) < 8 ? 'Password must be at least 8 characters' : null,
            ),
            const SizedBox(height: 20),
            _glassButton(
              onPressed: isLoading ? null : _register,
              isLoading: isLoading,
              label: 'Create Account',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _glassField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: !obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: Colors.white70,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6584)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6584)),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF6584)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _glassButton({required VoidCallback? onPressed, required bool isLoading, required String label}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Animated Logo ────────────────────────────────────────────────────────────

class _AnimatedLogo extends StatelessWidget {
  final AnimationController orbCtrl;
  const _AnimatedLogo({required this.orbCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: orbCtrl,
      builder: (_, child) {
        final scale = 1.0 + 0.04 * sin(orbCtrl.value * 2 * pi * 0.5);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFE91E63), Color(0xFFFF6D00), Color(0xFF7B1FA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: _kPink.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 5),
          ],
        ),
        child: const Center(
          child: Icon(Icons.favorite_rounded, size: 42, color: Colors.white),
        ),
      ),
    );
  }
}

// ── Floating Orbs Painter ────────────────────────────────────────────────────

class _OrbsPainter extends CustomPainter {
  final double t;
  _OrbsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = [
      _Orb(0.15, 0.20, 80, 0.7, 0.04),
      _Orb(0.80, 0.15, 60, 1.1, 0.03),
      _Orb(0.50, 0.75, 100, 0.9, 0.05),
      _Orb(0.85, 0.65, 70, 1.3, 0.035),
      _Orb(0.25, 0.55, 90, 0.8, 0.045),
    ];
    for (final o in orbs) {
      final dx = size.width * o.cx + sin(t * 2 * pi * o.speed) * 30;
      final dy = size.height * o.cy + cos(t * 2 * pi * o.speed * 0.7) * 25;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: o.alpha), Colors.white.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: Offset(dx, dy), radius: o.radius));
      canvas.drawCircle(Offset(dx, dy), o.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbsPainter old) => true;
}

class _Orb {
  final double cx, cy, radius, speed, alpha;
  const _Orb(this.cx, this.cy, this.radius, this.speed, this.alpha);
}

// ── Biometric Login View ─────────────────────────────────────────────────────

class _BiometricLoginView extends StatefulWidget {
  final String? userName;
  final bool loading;
  final VoidCallback onBiometric;
  final VoidCallback onUsePassword;
  final AnimationController orbCtrl;

  const _BiometricLoginView({
    required this.userName,
    required this.loading,
    required this.onBiometric,
    required this.onUsePassword,
    required this.orbCtrl,
  });

  @override
  State<_BiometricLoginView> createState() => _BiometricLoginViewState();
}

class _BiometricLoginViewState extends State<_BiometricLoginView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.92, end: 1.08).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userName?.split(' ').first ?? 'there';

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kPinkDark, _kPink, _kOrange],
              ),
            ),
          ),
          // Floating orbs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: widget.orbCtrl,
              builder: (_, __) => CustomPaint(painter: _OrbsPainter(widget.orbCtrl.value)),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AnimatedLogo(orbCtrl: widget.orbCtrl),
                    const SizedBox(height: 12),
                    const Text('Qorhealth',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 36),
                    Text('Welcome back, $name',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Sign in to continue',
                        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
                    const SizedBox(height: 48),
                    // Pulsing biometric icon
                    if (widget.loading)
                      const CircularProgressIndicator(color: Colors.white)
                    else
                      Semantics(
                        button: true,
                        label: 'Tap to authenticate with biometrics',
                        child: GestureDetector(
                          onTap: widget.onBiometric,
                          child: ScaleTransition(
                            scale: _scale,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.15),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                                boxShadow: [
                                  BoxShadow(color: _kPink.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5),
                                ],
                              ),
                              child: const Icon(Icons.fingerprint, size: 56, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: widget.loading ? null : widget.onBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Unlock with Biometrics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.onUsePassword,
                      child: Text('Use password instead',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
