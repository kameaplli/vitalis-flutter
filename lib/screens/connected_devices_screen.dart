import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sync_models.dart';
import '../providers/selected_person_provider.dart';
import '../providers/sync_provider.dart';
import '../services/health_sync_service.dart';
import '../services/oauth_service.dart';

class ConnectedDevicesScreen extends ConsumerStatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  ConsumerState<ConnectedDevicesScreen> createState() =>
      _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState
    extends ConsumerState<ConnectedDevicesScreen>
    with WidgetsBindingObserver {
  bool _syncing = false;
  SyncResult? _lastResult;
  bool _autoSyncOnOpen = false;
  bool _backgroundSync = false;
  bool _platformConnected = false;
  String? _lastSyncTime;
  bool _waitingForSettingsReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoSyncOnOpen = prefs.getBool('health_sync_auto') ?? false;
      _backgroundSync = prefs.getBool('health_sync_background') ?? false;
      _platformConnected = prefs.getBool('health_sync_connected') ?? false;
      final ms = prefs.getInt('health_sync_last_self') ?? 0;
      if (ms > 0) {
        _lastSyncTime = DateFormat('MMM d, y h:mm a')
            .format(DateTime.fromMillisecondsSinceEpoch(ms));
      }
    });
  }

  Future<void> _connectPlatform() async {
    if (!HealthSyncService.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Health sync is only available on iOS and Android devices'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecting to Health Connect...')),
      );
    }

    // Step 1: Check if Health Connect is even installed
    final hcAvailable = await HealthSyncService.isHealthConnectAvailable();
    if (!hcAvailable && Platform.isAndroid) {
      if (mounted) {
        final install = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.health_and_safety_rounded,
                size: 40, color: Theme.of(context).colorScheme.primary),
            title: const Text('Health Connect Required'),
            content: const Text(
                'Health Connect is not installed or not available on this device.\n\n'
                'Would you like to install it from the Play Store?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Not Now')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Install')),
            ],
          ),
        );
        if (install == true) {
          try {
            await Health().installHealthConnect();
          } catch (_) {
            await launchUrl(
              Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata'),
              mode: LaunchMode.externalApplication,
            );
          }
        }
      }
      return;
    }

    // Step 2: Request permissions (opens the Health Connect permission dialog)
    await HealthSyncService.requestPermissions();
    // Don't trust the return value — it's unreliable on many Android devices.

    // Step 3: The definitive test — try to actually read data
    final canRead = await HealthSyncService.canReadData();
    if (canRead) {
      await _markConnectedAndSync();
      return;
    }

    // Step 4: canReadData failed — offer manual setup
    if (mounted) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          icon: Icon(
            Icons.health_and_safety_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('Health Connect Setup'),
          content: Text(
            Platform.isIOS
                ? 'Please grant QoreHealth access to Apple Health data in Settings.'
                : 'Health Connect permissions could not be verified.\n\n'
                  'Please manually grant access:\n'
                  '1. Open Health Connect app\n'
                  '2. Tap "App permissions"\n'
                  '3. Find QoreHealth and allow all data types\n'
                  '4. Return to this app\n\n'
                  'If QoreHealth is not listed, tap "Connect" again after granting permissions in Health Connect.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Open Health Connect'),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        _waitingForSettingsReturn = true;
        await _openHealthSettings();
      }
    }
  }

  /// Mark the platform as connected, save pref, and trigger sync.
  Future<void> _markConnectedAndSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('health_sync_connected', true);
    if (!mounted) return;
    setState(() => _platformConnected = true);
    _loadPrefs();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Health Connect connected! Syncing...')),
    );
    _triggerSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettingsReturn) {
      _waitingForSettingsReturn = false;
      _recheckPermissionsAfterSettings();
    }
  }

  Future<void> _recheckPermissionsAfterSettings() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checking Health Connect access...')),
      );
    }

    // The definitive test: can we actually read data?
    final canRead = await HealthSyncService.canReadData();
    if (canRead) {
      await _markConnectedAndSync();
      return;
    }

    // Also try hasPermissions API as secondary check
    final granted = await HealthSyncService.hasPermissions();
    if (granted) {
      await _markConnectedAndSync();
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Could not access Health Connect data. '
            'Please ensure QoreHealth has permission in Health Connect app.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openHealthSettings() async {
    if (Platform.isAndroid) {
      // Open Health Connect app — user can manage app permissions there
      try {
        await Health().installHealthConnect();
      } catch (_) {
        // Fallback: open Health Connect in Play Store
        await launchUrl(
          Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata'),
          mode: LaunchMode.externalApplication,
        );
      }
    } else if (Platform.isIOS) {
      // Open iOS app settings where Health permissions are managed
      await launchUrl(
        Uri.parse('app-settings:'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _triggerSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    try {
      final person = ref.read(selectedPersonProvider);
      final result =
          await HealthSyncService.syncFromPlatform(person: person);
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _syncing = false;
      });

      // Reload last sync time
      _loadPrefs();

      // Invalidate sync status providers
      ref.invalidate(syncStatusProvider(person));
      ref.invalidate(connectedAccountsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync complete: ${result.inserted} new, '
              '${result.replaced} updated, ${result.skipped} skipped',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    }
  }

  Future<void> _forceFullResync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Force Full Resync'),
        content: const Text(
          'This will clear sync history and re-download the last 30 days '
          'of health data. This may take a few minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Resync'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Clear last sync timestamps
    final prefs = await SharedPreferences.getInstance();
    final keys =
        prefs.getKeys().where((k) => k.startsWith('health_sync_last_'));
    for (final key in keys) {
      await prefs.remove(key);
    }

    _triggerSync();
  }

  Future<void> _toggleAutoSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('health_sync_auto', value);
    if (mounted) setState(() => _autoSyncOnOpen = value);
  }

  Future<void> _toggleBackgroundSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('health_sync_background', value);
    if (mounted) setState(() => _backgroundSync = value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accountsAsync = ref.watch(connectedAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Devices'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // ── ON YOUR DEVICE section ──────────────────────────────────
          const _SectionHeader(label: 'ON YOUR DEVICE'),
          const SizedBox(height: 8),
          _PlatformHealthCard(
            isConnected: _platformConnected,
            isSyncing: _syncing,
            lastSyncTime: _lastSyncTime,
            lastResult: _lastResult,
            onConnect: _connectPlatform,
            onSync: _triggerSync,
          ),
          const SizedBox(height: 24),

          // ── CLOUD SERVICES section ──────────────────────────────────
          const _SectionHeader(label: 'CLOUD SERVICES'),
          const SizedBox(height: 8),
          ...accountsAsync.when(
            data: (accounts) => _buildCloudServiceCards(accounts),
            loading: () => _buildCloudServiceCards([]),
            error: (_, __) => _buildCloudServiceCards([]),
          ),
          const SizedBox(height: 24),

          // ── IMPORT DATA section ─────────────────────────────────────
          const _SectionHeader(label: 'IMPORT DATA'),
          const SizedBox(height: 8),
          const _ComingSoonCard(
            icon: Icons.upload_file_rounded,
            name: 'Import from other apps',
            description:
                'Import from MyFitnessPal, Cronometer, Apple Health export',
            color: Color(0xFF6366F1),
          ),
          const SizedBox(height: 24),

          // ── SYNC SETTINGS section ───────────────────────────────────
          const _SectionHeader(label: 'SYNC SETTINGS'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: cs.surfaceContainerLow,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Auto-sync on app open'),
                  subtitle: const Text(
                      'Automatically sync health data when you open the app'),
                  value: _autoSyncOnOpen,
                  onChanged: (v) {
                    if (!_platformConnected) {
                      _connectPlatform();
                    } else {
                      _toggleAutoSync(v);
                    }
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant.withValues(alpha: 0.3)),
                SwitchListTile(
                  title: const Text('Background sync'),
                  subtitle:
                      const Text('Sync health data periodically in background'),
                  value: _backgroundSync,
                  onChanged: (v) {
                    if (!_platformConnected) {
                      _connectPlatform();
                    } else {
                      _toggleBackgroundSync(v);
                    }
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant.withValues(alpha: 0.3)),
                ListTile(
                  title: const Text('Force full resync'),
                  subtitle:
                      const Text('Re-download last 30 days of health data'),
                  trailing:
                      Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant),
                  onTap: () {
                    if (!_platformConnected) {
                      _connectPlatform();
                    } else {
                      _forceFullResync();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── SYNC LOG section ────────────────────────────────────────
          if (_lastResult != null) ...[
            const _SectionHeader(label: 'LAST SYNC RESULT'),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: cs.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _SyncStatChip(
                      label: 'New',
                      value: _lastResult!.inserted,
                      color: const Color(0xFF22C55E),
                    ),
                    const SizedBox(width: 12),
                    _SyncStatChip(
                      label: 'Updated',
                      value: _lastResult!.replaced,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 12),
                    _SyncStatChip(
                      label: 'Skipped',
                      value: _lastResult!.skipped,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Build cloud service cards, matching connected accounts to platform definitions.
  List<Widget> _buildCloudServiceCards(List<ConnectedAccount> accounts) {
    final platforms = [
      _CloudPlatform(
        sourceId: 'fitbit',
        name: 'Fitbit',
        description: 'Sync activity, sleep & heart rate',
        icon: Icons.watch_rounded,
        color: const Color(0xFF00B0B9),
      ),
      _CloudPlatform(
        sourceId: 'garmin',
        name: 'Garmin',
        description: 'Sync workouts, body battery & stress',
        icon: Icons.watch_rounded,
        color: const Color(0xFF007CC3),
      ),
      _CloudPlatform(
        sourceId: 'withings',
        name: 'Withings',
        description: 'Sync weight, blood pressure & sleep',
        icon: Icons.scale_rounded,
        color: const Color(0xFF00C9B7),
      ),
      _CloudPlatform(
        sourceId: 'oura',
        name: 'Oura',
        description: 'Sync readiness, sleep & activity',
        icon: Icons.ring_volume_rounded,
        color: const Color(0xFFD4AF37),
      ),
      _CloudPlatform(
        sourceId: 'whoop',
        name: 'WHOOP',
        description: 'Sync strain, recovery & sleep',
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFF1A1A1A),
      ),
    ];

    final widgets = <Widget>[];
    for (final platform in platforms) {
      final account = accounts
          .where((a) => a.sourceId == platform.sourceId)
          .firstOrNull;

      widgets.add(_CloudServiceCard(
        platform: platform,
        account: account,
        onConnect: () => _connectCloudService(platform.sourceId),
        onDisconnect: account != null
            ? () => _disconnectCloudService(account.id, platform.name)
            : null,
        onResync: account != null && account.status == 'active'
            ? () => _resyncCloudService(account.id, platform.name)
            : null,
      ));
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Future<void> _connectCloudService(String sourceId) async {
    // Show loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to $sourceId...')),
    );

    final result = await OAuthService.startConnect(sourceId);
    if (result == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to connect to $sourceId. '
            'The service may not be configured yet.',
          ),
        ),
      );
      return;
    }

    final authUrl = result['auth_url'] as String?;
    if (authUrl == null || authUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No authorization URL received')),
      );
      return;
    }

    // Launch browser for OAuth
    final launched = await OAuthService.launchAuthUrl(authUrl);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open authorization page')),
      );
      return;
    }

    // Show dialog for manual code entry (fallback for when deep link doesn't work)
    if (!mounted) return;
    final code = await showDialog<String>(
      context: context,
      builder: (_) => _OAuthCodeDialog(sourceId: sourceId),
    );

    if (code != null && code.isNotEmpty) {
      final state = result['state'] as String? ?? '';
      // Extract code_verifier from state if present (Fitbit PKCE)
      String? codeVerifier;
      String actualState = state;
      if (state.contains('|')) {
        final parts = state.split('|');
        actualState = parts[0];
        codeVerifier = parts.length > 1 ? parts[1] : null;
      }

      final callbackResult = await OAuthService.completeCallback(
        sourceId: sourceId,
        code: code,
        state: actualState,
        codeVerifier: codeVerifier,
      );

      if (!mounted) return;
      if (callbackResult != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully connected to $sourceId!')),
        );
        ref.invalidate(connectedAccountsProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete $sourceId connection')),
        );
      }
    }
  }

  Future<void> _disconnectCloudService(String accountId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Disconnect $name?'),
        content: Text(
          'This will stop syncing data from $name. '
          'Previously synced data will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await OAuthService.disconnectPlatform(accountId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name disconnected')),
      );
      ref.invalidate(connectedAccountsProvider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to disconnect $name')),
      );
    }
  }

  Future<void> _resyncCloudService(String accountId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Resync $name?'),
        content: Text(
          'This will re-download all data from $name for the last 30 days. '
          'This may take a few minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Resync'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await OAuthService.forceResync(accountId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name resync initiated')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resync $name')),
      );
    }
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ── Platform health card (Apple Health / Health Connect) ─────────────────────

class _PlatformHealthCard extends StatelessWidget {
  final bool isConnected;
  final bool isSyncing;
  final String? lastSyncTime;
  final SyncResult? lastResult;
  final VoidCallback onConnect;
  final VoidCallback onSync;

  const _PlatformHealthCard({
    required this.isConnected,
    required this.isSyncing,
    this.lastSyncTime,
    this.lastResult,
    required this.onConnect,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isIOS = Platform.isIOS;
    final platformName = isIOS ? 'Apple Health' : 'Health Connect';
    final platformIcon = isIOS ? Icons.favorite_rounded : Icons.monitor_heart_rounded;
    final platformColor = isIOS ? const Color(0xFFFF2D55) : const Color(0xFF4285F4);
    final isSupported = HealthSyncService.isAvailable;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: platformColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(platformIcon, color: platformColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platformName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isConnected
                            ? 'Connected'
                            : (isSupported
                                ? 'Tap to connect'
                                : 'Not available on this device'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isConnected
                              ? const Color(0xFF22C55E)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isConnected && isSupported)
                  FilledButton(
                    onPressed: onConnect,
                    child: const Text('Connect'),
                  )
                else if (isConnected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Color(0xFF22C55E)),
                        SizedBox(width: 4),
                        Text(
                          'Connected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF22C55E),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (isSupported) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              // Last sync info
              if (lastSyncTime != null) ...[
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'Last sync: $lastSyncTime',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              // Data type badges
              const Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _DataTypeBadge(label: 'Steps', icon: Icons.directions_walk),
                  _DataTypeBadge(label: 'Heart Rate', icon: Icons.favorite),
                  _DataTypeBadge(label: 'Sleep', icon: Icons.bedtime),
                  _DataTypeBadge(label: 'Weight', icon: Icons.monitor_weight),
                  _DataTypeBadge(label: 'Workouts', icon: Icons.fitness_center),
                  _DataTypeBadge(label: 'Blood O2', icon: Icons.air),
                  _DataTypeBadge(label: 'Water', icon: Icons.water_drop),
                ],
              ),
              const SizedBox(height: 14),
              // Sync Now button — always visible on supported platforms
              SizedBox(
                width: double.infinity,
                child: isConnected
                    ? OutlinedButton.icon(
                        onPressed: isSyncing ? null : onSync,
                        icon: isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync, size: 18),
                        label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
                      )
                    : FilledButton.icon(
                        onPressed: onConnect,
                        icon: const Icon(Icons.sync, size: 18),
                        label: const Text('Connect & Sync Now'),
                      ),
              ),
              if (!isConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tap to grant Health Connect permissions and sync Samsung Health, Google Fit, or other health data.',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Data type badge ─────────────────────────────────────────────────────────

class _DataTypeBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _DataTypeBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cloud platform definition ───────────────────────────────────────────────

class _CloudPlatform {
  final String sourceId;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const _CloudPlatform({
    required this.sourceId,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// ── Cloud service card (replaces Coming Soon) ───────────────────────────────

class _CloudServiceCard extends StatelessWidget {
  final _CloudPlatform platform;
  final ConnectedAccount? account;
  final VoidCallback onConnect;
  final VoidCallback? onDisconnect;
  final VoidCallback? onResync;

  const _CloudServiceCard({
    required this.platform,
    this.account,
    required this.onConnect,
    this.onDisconnect,
    this.onResync,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isConnected = account != null && account!.status == 'active';
    final isError = account != null && (account!.status == 'error' || account!.status == 'expired');
    final isPending = account != null && account!.status == 'pending';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: platform.color.withValues(alpha: isConnected ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    platform.icon,
                    color: platform.color.withValues(alpha: isConnected ? 1.0 : 0.5),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platform.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        platform.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  _StatusBadge(
                    label: 'Connected',
                    color: const Color(0xFF22C55E),
                  )
                else if (isError)
                  _StatusBadge(
                    label: account!.status == 'expired' ? 'Expired' : 'Error',
                    color: cs.error,
                  )
                else if (isPending)
                  _StatusBadge(
                    label: 'Pending',
                    color: const Color(0xFFF59E0B),
                  )
                else
                  FilledButton.tonal(
                    onPressed: onConnect,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Connect', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),

            // Show error message
            if (isError && account?.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: cs.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        account!.errorMessage!,
                        style: TextStyle(fontSize: 11, color: cs.error),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons for connected/error accounts
            if (isConnected || isError) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onResync != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onResync,
                        icon: const Icon(Icons.sync, size: 14),
                        label: const Text('Resync', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ),
                  if (onResync != null && isError)
                    const SizedBox(width: 8),
                  if (isError)
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: onConnect,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Reconnect', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  if (onResync != null || isError)
                    const SizedBox(width: 8),
                  if (onDisconnect != null)
                    TextButton(
                      onPressed: onDisconnect,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        foregroundColor: cs.error,
                      ),
                      child: const Text('Disconnect', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Coming soon card (kept for Import section) ──────────────────────────────

class _ComingSoonCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  final Color color;

  const _ComingSoonCard({
    required this.icon,
    required this.name,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color.withValues(alpha: 0.5), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sync stat chip ──────────────────────────────────────────────────────────

class _SyncStatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SyncStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── OAuth code entry dialog ─────────────────────────────────────────────────

class _OAuthCodeDialog extends StatefulWidget {
  final String sourceId;
  const _OAuthCodeDialog({required this.sourceId});

  @override
  State<_OAuthCodeDialog> createState() => _OAuthCodeDialogState();
}

class _OAuthCodeDialogState extends State<_OAuthCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Complete ${widget.sourceId} Connection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'After authorizing in the browser, paste the authorization code '
            'from the callback URL here:',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Authorization code',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            autofocus: true,
            onSubmitted: (v) {
              if (v.isNotEmpty) Navigator.pop(context, v);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final code = _controller.text.trim();
            if (code.isNotEmpty) {
              Navigator.pop(context, code);
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
