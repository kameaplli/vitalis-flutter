import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Returns a user-friendly error message based on the error type.
/// Avoids generic "Something went wrong" — gives actionable, contextual info.
String friendlyErrorMessage(Object error, {String? context}) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please check your internet and try again.';
      case DioExceptionType.connectionError:
        return 'Unable to connect to the server. Please check your internet connection.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 401) return 'Your session has expired. Please sign in again.';
        if (code == 403) return 'You don\'t have permission to view this data.';
        if (code == 404) return 'The requested data was not found.';
        if (code == 422) return 'Invalid request. Please try again.';
        if (code != null && code >= 500) return 'The server is temporarily unavailable. Please try again later.';
        return 'Failed to load data. Please try again.';
      case DioExceptionType.cancel:
        return 'Request was cancelled. Please try again.';
      default:
        return 'Unable to load data. Please check your connection and try again.';
    }
  }

  if (error is SocketException) {
    return 'No internet connection. Please check your network and try again.';
  }

  if (error is FormatException) {
    return 'Received unexpected data from the server. Please try again.';
  }

  // Fallback
  final ctx = context != null ? context : 'data';
  return 'Unable to load $ctx right now. Pull down to refresh.';
}

/// A friendly, visually appealing error widget for center-of-screen errors.
class FriendlyError extends StatelessWidget {
  final Object error;
  final String? context; // e.g. "symptoms", "nutrition", "weight history"
  final VoidCallback? onRetry;

  const FriendlyError({
    super.key,
    required this.error,
    this.context,
    this.onRetry,
  });

  @override
  Widget build(BuildContext ctx) {
    final message = friendlyErrorMessage(error, context: context);
    final cs = Theme.of(ctx).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconForError(error),
              size: 48,
              color: cs.outline,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForError(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return Icons.wifi_off_rounded;
      }
      if (error.type == DioExceptionType.badResponse) {
        final code = error.response?.statusCode;
        if (code == 401) return Icons.lock_outline_rounded;
        if (code == 403) return Icons.block_rounded;
        if (code != null && code >= 500) return Icons.cloud_off_rounded;
      }
    }
    if (error is SocketException) return Icons.wifi_off_rounded;
    return Icons.error_outline_rounded;
  }
}

/// A simple empty-state widget for when data loads successfully but is empty.
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.outline.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
