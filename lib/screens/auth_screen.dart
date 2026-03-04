import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
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
        if (mounted) setState(() => _bioLoading = false);
        return;
      }
      final creds = await SecureStorage.getBioCredentials();
      if (creds.email == null || creds.password == null) {
        // Credentials missing — fall back
        await SecureStorage.clearBioCredentials();
        if (mounted) setState(() { _showBiometricLogin = false; _bioLoading = false; });
        return;
      }
      final loginOk = await ref.read(authProvider.notifier).login(creds.email!, creds.password!);
      if (!mounted) return;
      if (!loginOk) {
        // 401 or network error — clear stored creds and fall back to password form
        await SecureStorage.clearBioCredentials();
        if (!mounted) return;
        setState(() { _showBiometricLogin = false; _bioLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric login failed — please sign in with your password')),
        );
      }
      // On success: GoRouter redirect will take the user to /dashboard automatically
    } catch (_) {
      if (mounted) setState(() => _bioLoading = false);
    }
  }

  Future<void> _offerBiometrics(String email, String password, String name) async {
    final available = await BiometricService.isAvailable();
    if (!available) return;
    // Skip if already enabled
    final alreadyEnabled = await SecureStorage.getBiometricsEnabled();
    if (alreadyEnabled) return;
    // Skip only if user explicitly tapped "Not now" before
    final declined = await SecureStorage.getBiometricsPrompted();
    if (declined) return;
    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BiometricOfferDialog(),
    );
    if (enable != true) {
      // User explicitly declined — set prompted so we never ask again
      await SecureStorage.setBiometricsPrompted(true);
      return;
    }
    // User wants to enable — confirm with biometric
    final confirmed = await BiometricService.authenticate(reason: 'Confirm to enable biometric login');
    if (!confirmed) {
      // Do NOT set prompted here — user wanted to enable but something went wrong.
      // They'll be offered again next login or can enable via Profile.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric setup skipped — enable it anytime in Profile')),
        );
      }
      return;
    }
    await SecureStorage.saveBioCredentials(email: email, password: password, name: name);
    await SecureStorage.setBiometricsEnabled(true);
    await SecureStorage.setBiometricsPrompted(true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric login enabled ✓')),
      );
    }
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
      _loginEmail.text.trim(),
      _loginPassword.text,
    );
    if (!mounted) return;
    if (ok) {
      final user = ref.read(authProvider).user;
      await _offerBiometrics(
        _loginEmail.text.trim(),
        _loginPassword.text,
        user?.name ?? 'User',
      );
    } else {
      final err = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Login failed')));
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
      await _offerBiometrics(
        _regEmail.text.trim(),
        _regPassword.text,
        user?.name ?? _regName.text.trim(),
      );
    } else {
      final err = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Registration failed')));
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
// Biometric offer dialog — shown once after a successful password login
// ---------------------------------------------------------------------------

class _BiometricOfferDialog extends StatelessWidget {
  const _BiometricOfferDialog();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Faster sign-ins'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fingerprint, size: 64, color: cs.primary),
          const SizedBox(height: 12),
          const Text(
            'Use your fingerprint or face to sign in next time. '
            'Your password stays safe on this device.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Enable'),
        ),
      ],
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
