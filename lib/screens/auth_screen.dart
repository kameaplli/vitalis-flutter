import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../core/biometric_offer.dart';
import '../core/secure_storage.dart';
import '../services/biometric_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    _checkBiometrics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _regName.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final enabled = await SecureStorage.getBiometricsEnabled();
    final available = await BiometricService.isAvailable();
    if (!enabled || !available) return;
    final creds = await SecureStorage.getBioCredentials();
    // Credentials missing means biometrics were enabled (e.g. via Profile toggle
    // on an old build) but the password was never stored.  Don't show the
    // biometric screen — user must log in once with password to store them.
    if (creds.email == null || creds.password == null) return;
    if (!mounted) return;
    setState(() {
      _showBiometricLogin = true;
      _bioUserName = creds.name;
    });
    // Auto-prompt after a short delay so the screen is fully rendered
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && _showBiometricLogin) _triggerBiometric();
    });
  }

  Future<void> _triggerBiometric() async {
    if (_bioLoading) return;
    setState(() => _bioLoading = true);
    try {
      final ok = await BiometricService.authenticate(reason: 'Sign in to Vitalis');
      if (!ok) {
        // User cancelled or scan failed — reset silently so they can retry
        if (mounted) setState(() => _bioLoading = false);
        return;
      }
      final creds = await SecureStorage.getBioCredentials();
      if (creds.email == null || creds.password == null) {
        // Credentials missing — fall back without disabling biometrics
        if (mounted) setState(() { _showBiometricLogin = false; _bioLoading = false; });
        return;
      }
      final loginOk = await ref.read(authProvider.notifier).login(creds.email!, creds.password!);
      if (!mounted) return;
      if (!loginOk) {
        final err = ref.read(authProvider).error ?? '';
        // Only clear credentials on a 401 (wrong password). Network errors /
        // Railway cold-starts return generic errors — keep creds so the user
        // can retry without re-entering their password.
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
          // Network / server error — keep credentials, let user retry
          if (!mounted) return;
          setState(() => _bioLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connection error — check your connection and try again')),
          );
        }
      }
      // On success: GoRouter redirect will take the user to /dashboard automatically
    } catch (_) {
      if (mounted) setState(() => _bioLoading = false);
    }
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final email    = _loginEmail.text.trim();
    final password = _loginPassword.text;
    final ok = await ref.read(authProvider.notifier).login(email, password);
    if (!mounted) return;
    if (ok) {
      final user = ref.read(authProvider).user;
      final name = user?.name ?? 'User';
      await _postLoginBioSetup(email, password, name);
    } else {
      final err = ref.read(authProvider).error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err ?? 'Login failed')));
    }
  }

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).register(
      _regName.text.trim(),
      _regEmail.text.trim(),
      _regPassword.text,
    );
    if (!mounted) return;
    if (ok) {
      final user = ref.read(authProvider).user;
      await _postLoginBioSetup(
        _regEmail.text.trim(),
        _regPassword.text,
        user?.name ?? _regName.text.trim(),
      );
    } else {
      final err = ref.read(authProvider).error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err ?? 'Registration failed')));
    }
  }

  /// Called after a successful login or register.
  /// - If biometrics are available but not yet enabled: queue an offer for
  ///   AppShell to show after navigation (avoids the unmount race).
  /// - If biometrics are already enabled but no credentials stored (user
  ///   toggled ON from Profile): auto-save credentials silently now.
  Future<void> _postLoginBioSetup(
      String email, String password, String name) async {
    final available = await BiometricService.isAvailable();
    final enabled   = await SecureStorage.getBiometricsEnabled();

    if (available && !enabled) {
      // Queue for AppShell — cannot show dialog here because GoRouter will
      // unmount AuthScreen on the next frame, causing !mounted to cancel it.
      BiometricOffer.queue(email, password, name);
    } else if (enabled) {
      final existing = await SecureStorage.getBioCredentials();
      if (existing.password == null || existing.password!.isEmpty) {
        await SecureStorage.saveBioCredentials(
            email: email, password: password, name: name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showBiometricLogin) {
      return _BiometricLoginView(
        userName: _bioUserName,
        loading: _bioLoading,
        onBiometric: _triggerBiometric,
        onUsePassword: () => setState(() => _showBiometricLogin = false),
      );
    }

    final isLoading = ref.watch(authProvider).isLoading;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Icon(Icons.favorite, size: 56, color: cs.primary),
              const SizedBox(height: 8),
              Text('Vitalis', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold, color: cs.primary)),
              Text('Health & Nutrition Tracker', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),
              TabBar(controller: _tabController, tabs: const [Tab(text: 'Sign In'), Tab(text: 'Register')]),
              const SizedBox(height: 24),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Login tab
                    Form(
                      key: _loginFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _loginEmail,
                            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v?.isEmpty ?? true) ? 'Email required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _loginPassword,
                            obscureText: _obscureLogin,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureLogin ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscureLogin = !_obscureLogin),
                              ),
                            ),
                            validator: (v) => (v?.isEmpty ?? true) ? 'Password required' : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: isLoading ? null : _login,
                              child: isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Sign In'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Register tab
                    Form(
                      key: _registerFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _regName,
                            decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                            validator: (v) => (v?.isEmpty ?? true) ? 'Name required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _regEmail,
                            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v?.isEmpty ?? true) ? 'Email required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _regPassword,
                            obscureText: _obscureReg,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureReg ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscureReg = !_obscureReg),
                              ),
                            ),
                            validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: isLoading ? null : _register,
                              child: isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Create Account'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Biometric login view — shown instead of the tab form when biometrics are on
// ---------------------------------------------------------------------------

class _BiometricLoginView extends StatefulWidget {
  final String? userName;
  final bool loading;
  final VoidCallback onBiometric;
  final VoidCallback onUsePassword;

  const _BiometricLoginView({
    required this.userName,
    required this.loading,
    required this.onBiometric,
    required this.onUsePassword,
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
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = widget.userName?.split(' ').first ?? 'there';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite, size: 48, color: cs.primary),
                const SizedBox(height: 8),
                Text('Vitalis',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
                const SizedBox(height: 32),
                Text('Welcome back, $name',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Sign in to continue',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 48),
                // Pulsing biometric icon
                if (widget.loading)
                  const CircularProgressIndicator()
                else
                  ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primaryContainer,
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(Icons.fingerprint,
                          size: 56, color: cs.primary),
                    ),
                  ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.loading ? null : widget.onBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock with Biometrics'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onUsePassword,
                  child: const Text('Use password instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
