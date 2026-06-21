import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

class DropboxService {
  static const _clientId = 'q39vgbb6gks3474';
  static const _redirectUri = 'sonarpad://dropbox';
  static const _tokenKey = 'dropbox_access_token';
  static const _refreshTokenKey = 'dropbox_refresh_token';

  String? _accessToken;
  String? _refreshToken;

  bool get isAuthenticated => _accessToken != null || _refreshToken != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);

    // Older Sonarpad builds stored only the short-lived access token.
    // If that token is now expired there is no way to refresh it silently,
    // so the user will be asked to log in once again. New logins store the
    // refresh token and can recover automatically.
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Future<bool> authenticate() async {
    try {
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      final authUrl = Uri.https('www.dropbox.com', '/oauth2/authorize', {
        'client_id': _clientId,
        'response_type': 'code',
        'code_challenge_method': 'S256',
        'code_challenge': codeChallenge,
        'redirect_uri': _redirectUri,
        'token_access_type': 'offline',
      });

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: 'sonarpad',
      );

      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) throw Exception('Codice di autorizzazione non trovato');

      final tokenResponse = await http.post(
        Uri.https('api.dropboxapi.com', '/oauth2/token'),
        body: {
          'client_id': _clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'code_verifier': codeVerifier,
          'redirect_uri': _redirectUri,
        },
      );

      if (tokenResponse.statusCode == 200) {
        final data = jsonDecode(tokenResponse.body);
        _accessToken = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        if (_accessToken == null) {
          throw Exception('Token Dropbox non ricevuto');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, _accessToken!);
        if (_refreshToken != null && _refreshToken!.isNotEmpty) {
          await prefs.setString(_refreshTokenKey, _refreshToken!);
        }
        return true;
      } else {
        throw Exception('Errore nel login Dropbox: ${tokenResponse.body}');
      }
    } catch (e) {
      dev.log('Dropbox auth error: $e');
      return false;
    }
  }

  String _generateCodeVerifier() {
    final random = math.Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  Future<List<Map<String, dynamic>>> listFolder(String path) async {
    final response = await _sendDropboxRequestWithRefresh(
      () => http.post(
        Uri.https('api.dropboxapi.com', '/2/files/list_folder'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'path': path,
          'limit': 1000,
        }),
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final entries = data['entries'] as List<dynamic>;
      return entries.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Errore elenco cartella: ${response.body}');
    }
  }

  Future<List<int>> downloadFile(String path) async {
    final response = await _sendDropboxRequestWithRefresh(
      () => http.post(
        Uri.https('content.dropboxapi.com', '/2/files/download'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Dropbox-API-Arg': jsonEncode({'path': path}),
        },
      ),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Errore download file: ${response.body}');
    }
  }

  Future<http.Response> _sendDropboxRequestWithRefresh(
    Future<http.Response> Function() request,
  ) async {
    if (_accessToken == null) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) throw DropboxAuthRequiredException();
    }

    var response = await request();
    if (!_isExpiredAccessTokenResponse(response)) return response;

    dev.log('Dropbox access token expired, attempting refresh');
    final refreshed = await _refreshAccessToken();
    if (!refreshed) {
      await _clearAccessTokenOnly();
      throw DropboxAuthRequiredException();
    }

    response = await request();
    if (_isExpiredAccessTokenResponse(response)) {
      await logout();
      throw DropboxAuthRequiredException();
    }
    return response;
  }

  bool _isExpiredAccessTokenResponse(http.Response response) {
    if (response.statusCode != 400 && response.statusCode != 401) {
      return false;
    }

    return response.body.contains('expired_access_token') ||
        response.body.contains('invalid_access_token');
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.https('api.dropboxapi.com', '/oauth2/token'),
        body: {
          'client_id': _clientId,
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
        },
      );

      if (response.statusCode != 200) {
        dev.log('Dropbox token refresh failed: ${response.body}');
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newAccessToken = data['access_token'] as String?;
      if (newAccessToken == null || newAccessToken.isEmpty) return false;

      _accessToken = newAccessToken;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, newAccessToken);
      dev.log('Dropbox access token refreshed');
      return true;
    } catch (e) {
      dev.log('Dropbox token refresh error: $e');
      return false;
    }
  }

  Future<void> _clearAccessTokenOnly() async {
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}

class DropboxAuthRequiredException implements Exception {
  @override
  String toString() => 'Dropbox authorization required';
}
