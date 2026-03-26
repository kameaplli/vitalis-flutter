import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import 'health_provider.dart';

/// Tracks which supplements have been taken today with optimistic local-first
/// state. The UI shows the tick instantly; the API call runs in the background
/// with up to 3 retries. Failed syncs revert the local state and surface an
/// error the UI can display.

// ─── State ───────────────────────────────────────────────────────────────────

class SupplementIntakeState {
  /// Supplement IDs marked as taken today (local optimistic state).
  final Set<String> takenToday;

  /// Supplement IDs currently syncing to backend.
  final Set<String> syncing;

  /// Map of supplement ID → error message for failed syncs.
  final Map<String, String> errors;

  const SupplementIntakeState({
    this.takenToday = const {},
    this.syncing = const {},
    this.errors = const {},
  });

  SupplementIntakeState copyWith({
    Set<String>? takenToday,
    Set<String>? syncing,
    Map<String, String>? errors,
  }) =>
      SupplementIntakeState(
        takenToday: takenToday ?? this.takenToday,
        syncing: syncing ?? this.syncing,
        errors: errors ?? this.errors,
      );

  bool isTaken(String id) => takenToday.contains(id);
  bool isSyncing(String id) => syncing.contains(id);
  String? errorFor(String id) => errors[id];
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class SupplementIntakeNotifier extends StateNotifier<SupplementIntakeState> {
  final Ref _ref;
  static const _storageKey = 'supplement_intake_local';

  SupplementIntakeNotifier(this._ref) : super(const SupplementIntakeState()) {
    _loadFromDisk();
  }

  // ── Persistence (survives app restart within same day) ──────────────────

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final storedDate = data['date'] as String?;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (storedDate != today) {
        // Stale data from a previous day — discard
        await prefs.remove(_storageKey);
        return;
      }
      final ids = (data['ids'] as List<dynamic>?)?.cast<String>().toSet() ?? {};
      if (ids.isNotEmpty) {
        state = state.copyWith(takenToday: {...state.takenToday, ...ids});
      }
    } catch (_) {}
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await prefs.setString(_storageKey, jsonEncode({
        'date': today,
        'ids': state.takenToday.toList(),
      }));
    } catch (_) {}
  }

  /// Seed the local state from server data (call after supplements load).
  void seedFromServer(List<HealthMap> supplements) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final serverTaken = <String>{};
    for (final s in supplements) {
      if (s['last_intake_date'] == today) {
        serverTaken.add(s['id']?.toString() ?? '');
      }
    }
    serverTaken.remove('');
    if (serverTaken.isNotEmpty) {
      state = state.copyWith(takenToday: {...state.takenToday, ...serverTaken});
      _saveToDisk();
    }
  }

  // ── Optimistic log intake ──────────────────────────────────────────────

  /// Mark as taken instantly (optimistic), then sync to backend in background.
  /// Returns immediately — the UI updates before the API call completes.
  void logIntake(String supplementId, String supplementName, String personKey) {
    if (state.takenToday.contains(supplementId)) return; // already taken

    // 1. Optimistic local update
    state = state.copyWith(
      takenToday: {...state.takenToday, supplementId},
      syncing: {...state.syncing, supplementId},
      errors: Map.of(state.errors)..remove(supplementId),
    );
    _saveToDisk();

    // 2. Background sync with retry
    _syncToBackend(supplementId, supplementName, personKey);
  }

  Future<void> _syncToBackend(
    String supplementId,
    String supplementName,
    String personKey, {
    int attempt = 1,
    int maxAttempts = 3,
  }) async {
    try {
      await apiClient.dio.post(ApiConstants.supplementLogIntake(supplementId));

      // Success — remove from syncing set
      state = state.copyWith(
        syncing: Set.of(state.syncing)..remove(supplementId),
      );

      // Refresh server data in background (non-blocking)
      _ref.invalidate(supplementsProvider(personKey));
      _ref.invalidate(supplementsCatalogProvider);
    } catch (e) {
      if (attempt < maxAttempts) {
        // Exponential backoff: 1s, 2s, 4s
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        if (!mounted) return;
        return _syncToBackend(
          supplementId, supplementName, personKey,
          attempt: attempt + 1,
          maxAttempts: maxAttempts,
        );
      }

      // All retries exhausted — revert optimistic state and surface error
      state = state.copyWith(
        takenToday: Set.of(state.takenToday)..remove(supplementId),
        syncing: Set.of(state.syncing)..remove(supplementId),
        errors: {
          ...state.errors,
          supplementId: 'Failed to log $supplementName. Tap to retry.',
        },
      );
      _saveToDisk();
    }
  }

  /// Retry a failed sync.
  void retry(String supplementId, String supplementName, String personKey) {
    state = state.copyWith(
      errors: Map.of(state.errors)..remove(supplementId),
    );
    logIntake(supplementId, supplementName, personKey);
  }

  /// Clear error for a supplement (user dismissed it).
  void dismissError(String supplementId) {
    state = state.copyWith(
      errors: Map.of(state.errors)..remove(supplementId),
    );
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final supplementIntakeProvider =
    StateNotifierProvider<SupplementIntakeNotifier, SupplementIntakeState>(
  (ref) {
    final notifier = SupplementIntakeNotifier(ref);
    return notifier;
  },
);
