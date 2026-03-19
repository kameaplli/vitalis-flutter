import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

/// Handles OAuth2 connection flows for cloud wearable platforms.
///
/// The flow:
/// 1. Call [connectPlatform] with the sourceId (e.g., "fitbit").
/// 2. Backend returns an OAuth2 auth URL.
/// 3. We launch that URL in the system browser.
/// 4. User authorizes on the platform's site.
/// 5. Platform redirects back with a code.
/// 6. App calls [completeCallback] with the code to exchange for tokens.
class OAuthService {
  /// Start OAuth2 connection flow for a platform.
  ///
  /// Returns a map with:
  /// - "auth_url": the URL to open in the browser
  /// - "state": CSRF state token
  /// - "account_id": the pending ConnectedAccount ID
  ///
  /// Returns null if the request fails.
  static Future<Map<String, dynamic>?> startConnect(String sourceId) async {
    try {
      // Use a deep link URI for the callback
      // In production, this would be a registered custom URL scheme
      const redirectUri = 'qorehealth://oauth/callback';

      final resp = await apiClient.dio.post(
        ApiConstants.syncConnect,
        data: {
          'source_id': sourceId,
          'redirect_uri': redirectUri,
        },
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return resp.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('OAuthService.startConnect error: $e');
      return null;
    }
  }

  /// Launch the OAuth2 authorization URL in the system browser.
  static Future<bool> launchAuthUrl(String authUrl) async {
    final uri = Uri.parse(authUrl);
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('OAuthService.launchAuthUrl error: $e');
      return false;
    }
  }

  /// Complete the OAuth2 flow by sending the authorization code to the backend.
  ///
  /// Returns the connected account info or null on failure.
  static Future<Map<String, dynamic>?> completeCallback({
    required String sourceId,
    required String code,
    required String state,
    String? codeVerifier,
  }) async {
    try {
      const redirectUri = 'qorehealth://oauth/callback';

      final data = <String, dynamic>{
        'source_id': sourceId,
        'code': code,
        'state': state,
        'redirect_uri': redirectUri,
      };
      if (codeVerifier != null) {
        data['code_verifier'] = codeVerifier;
      }

      final resp = await apiClient.dio.post(
        ApiConstants.syncCallback,
        data: data,
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return resp.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('OAuthService.completeCallback error: $e');
      return null;
    }
  }

  /// Disconnect a cloud platform account.
  static Future<bool> disconnectPlatform(String accountId) async {
    try {
      final resp = await apiClient.dio.delete(
        ApiConstants.syncDisconnect(accountId),
      );
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('OAuthService.disconnectPlatform error: $e');
      return false;
    }
  }

  /// Force a full resync for a connected account.
  static Future<bool> forceResync(String accountId) async {
    try {
      final resp = await apiClient.dio.post(
        ApiConstants.syncResync(accountId),
      );
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('OAuthService.forceResync error: $e');
      return false;
    }
  }
}
