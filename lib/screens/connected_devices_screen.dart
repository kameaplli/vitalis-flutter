import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_models.dart';
import '../providers/selected_person_provider.dart';
import '../providers/sync_provider.dart';
import '../services/health_sync_service.dart';

class ConnectedDevicesScreen extends ConsumerStatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  ConsumerState<ConnectedDevicesScreen> createState() =>
      _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState
    extends ConsumerState<ConnectedDevicesScreen> {
  bool _syncing = false;
  SyncResult? _lastResult;
  bool _autoSyncOnOpen = false;
  bool _backgroundSync = false;
  bool _platformConnected = false;
  String? _lastSyncTime;

  @override
  void initState() {
    super.initState();
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

    final granted = await HealthSyncService.requestPermissions();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health permissions were denied. '
                'Please grant access in your device settings.'),
          ),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('health_sync_connected', true);
    if (!mounted) return;
    setState(() => _platformConnected = true);

    // Trigger initial sync
    _triggerSync();
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
      builder: (_) => AlertDialog(
        title: const Text('Force Full Resync'),
        content: const Text(
          'This will clear sync history and re-download the last 30 days '
          'of health data. This may take a few minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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
          const _ComingSoonCard(
            icon: Icons.watch_rounded,
            name: 'Fitbit',
            description: 'Sync activity, sleep & heart rate',
            color: Color(0xFF00B0B9),
          ),
          const SizedBox(height: 8),
          const _ComingSoonCard(
            icon: Icons.watch_rounded,
            name: 'Garmin',
            description: 'Sync workouts, body battery & stress',
            color: Color(0xFF007CC3),
          ),
          const SizedBox(height: 8),
          const _ComingSoonCard(
            icon: Icons.scale_rounded,
            name: 'Withings',
            description: 'Sync weight, blood pressure & sleep',
            color: Color(0xFF00C9B7),
          ),
          const SizedBox(height: 8),
          const _ComingSoonCard(
            icon: Icons.ring_volume_rounded,
            name: 'Oura',
            description: 'Sync readiness, sleep & activity',
            color: Color(0xFFD4AF37),
          ),
          const SizedBox(height: 8),
          const _ComingSoonCard(
            icon: Icons.fitness_center_rounded,
            name: 'WHOOP',
            description: 'Sync strain, recovery & sleep',
            color: Color(0xFF1A1A1A),
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
                  onChanged: _platformConnected ? _toggleAutoSync : null,
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant.withValues(alpha: 0.3)),
                SwitchListTile(
                  title: const Text('Background sync'),
                  subtitle:
                      const Text('Sync health data periodically in background'),
                  value: _backgroundSync,
                  onChanged: _platformConnected ? _toggleBackgroundSync : null,
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant.withValues(alpha: 0.3)),
                ListTile(
                  title: const Text('Force full resync'),
                  subtitle:
                      const Text('Re-download last 30 days of health data'),
                  trailing:
                      Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant),
                  onTap: _platformConnected ? _forceFullResync : null,
                  enabled: _platformConnected,
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
            if (isConnected) ...[
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
              // Manual sync button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isSyncing ? null : onSync,
                  icon: isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 18),
                  label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
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

// ── Coming soon card ────────────────────────────────────────────────────────

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
