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

  String? _accessToken;

  bool get isAuthenticated => _accessToken != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
  }

  Future<void> logout() async {
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
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
        _accessToken = data['access_token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, _accessToken!);
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
    if (_accessToken == null) throw Exception('Non autenticato');

    final response = await http.post(
      Uri.https('api.dropboxapi.com', '/2/files/list_folder'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'path': path,
        'limit': 1000,
      }),
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
    if (_accessToken == null) throw Exception('Non autenticato');

    final response = await http.post(
      Uri.https('content.dropboxapi.com', '/2/files/download'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Dropbox-API-Arg': jsonEncode({'path': path}),
      },
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Errore download file: ${response.body}');
    }
  }
}
