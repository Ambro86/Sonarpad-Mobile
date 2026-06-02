import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class BdCiechiQuota {
  final String remaining;
  final String monthlyTotal;

  BdCiechiQuota({required this.remaining, required this.monthlyTotal});
}

class BdCiechiIdentifyResponse {
  final String nprov;
  final BdCiechiQuota? quota;

  BdCiechiIdentifyResponse({required this.nprov, this.quota});
}

class BdCiechiWorkResponse {
  final String info;
  final List<int> textBytes;

  BdCiechiWorkResponse({required this.info, required this.textBytes});

  String get decodedText {
    return _decodeServerText(textBytes);
  }
}

String _decodeServerText(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    // Fallback a latin1 (ISO-8859-1 / Windows-1252 compatibile) per preservare gli accenti
    return latin1.decode(bytes);
  }
}

class BdCiechiService {
  static const String _baseUrl = 'https://www.bdciechi.it/route.php';

  static String get _idenSp {
    if (Platform.isIOS) return 'SPiOS';
    if (Platform.isAndroid) return 'SPAnd';
    return 'SP';
  }

  String _cifra(String input) {
    int len = input.length;
    List<int> v = List.filled(len + 1, 0);
    for (int i = 0; i < len; i++) {
      v[0] += input.codeUnitAt(i);
    }
    v[0] %= 256;
    for (int i = 0; i < len; i++) {
      v[i + 1] = v[i] ^ input.codeUnitAt(i);
    }
    String out = '';
    for (int n in v) {
      out += (n & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();
    }
    return out;
  }

  String _rnd() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  bool _isProtocolError(String text) {
    return text.trimLeft().startsWith('!');
  }

  Future<BdCiechiIdentifyResponse> identify(
      String username, String password) async {
    final queryPlain = '$_idenSp;$username;$password;*;${_rnd()}';
    final queryEnc = _cifra(queryPlain);
    final url = Uri.parse('$_baseUrl?$queryEnc');

    final response = await http.get(url).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw Exception('Errore di rete HTTP ${response.statusCode}');
    }

    final body = _decodeServerText(response.bodyBytes);
    if (_isProtocolError(body)) {
      throw Exception(body);
    }

    final parts = body.trim().split(';');
    if (parts.isEmpty || parts[0].trim().isEmpty) {
      throw Exception('Risposta identificazione non valida');
    }

    final nprov = parts[0].trim();
    BdCiechiQuota? quota;
    if (parts.length > 1 && parts[1].trim().isNotEmpty) {
      final remaining = parts[1].trim();
      final monthlyTotal = (parts.length > 2 && parts[2].trim().isNotEmpty)
          ? parts[2].trim()
          : '60';
      quota = BdCiechiQuota(remaining: remaining, monthlyTotal: monthlyTotal);
    }

    return BdCiechiIdentifyResponse(nprov: nprov, quota: quota);
  }

  Future<List<String>> fetchCatalogList(String nprov) async {
    final url = Uri.parse('$_baseUrl?-ele;@$nprov;${_rnd()}');
    final response = await http.get(url).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw Exception('Errore di rete HTTP ${response.statusCode}');
    }

    final body = _decodeServerText(response.bodyBytes);
    if (_isProtocolError(body)) {
      throw Exception(body);
    }

    return _parseCatalogRecords(body);
  }

  Future<List<String>> fetchLatestList(String nprov) async {
    final url = Uri.parse('$_baseUrl?-ult;@$nprov;${_rnd()}');
    final response = await http.get(url).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw Exception('Errore di rete HTTP ${response.statusCode}');
    }

    final body = _decodeServerText(response.bodyBytes);
    if (_isProtocolError(body)) {
      throw Exception(body);
    }

    return _parseCatalogRecords(body);
  }

  List<String> _parseCatalogRecords(String raw) {
    return raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.startsWith('['))
        .toList();
  }

  Future<BdCiechiWorkResponse> downloadWork(
    String username,
    String password,
    String index,
    bool preview,
  ) async {
    final utc =
        DateFormat('yyyy-MM-dd HH.mm.ss').format(DateTime.now().toUtc());
    final sample = preview ? '+' : '';
    final queryPlain = '$_idenSp;$username;$password;$index;$utc;$sample;150';
    final queryEnc = _cifra(queryPlain);
    final url = Uri.parse('$_baseUrl?$queryEnc');

    final response = await http.get(url).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw Exception('Errore di rete HTTP ${response.statusCode}');
    }

    final bytes = response.bodyBytes;
    if (bytes.isNotEmpty && bytes[0] == 33) {
      // 33 is '!'
      final text = _decodeServerText(bytes);
      if (_isProtocolError(text)) {
        throw Exception(text);
      }
    }

    final pos = bytes.indexOf(26); // EOF character (Ctrl+Z)
    if (pos != -1) {
      final infoBytes = bytes.sublist(0, pos);
      final textBytes = bytes.sublist(pos + 1);
      final info = _decodeServerText(infoBytes);
      return BdCiechiWorkResponse(info: info, textBytes: textBytes);
    }

    return BdCiechiWorkResponse(info: '', textBytes: bytes);
  }

  BdCiechiQuota? parseWorkQuota(String info) {
    final parts = info.trim().split(';');
    if (parts.length < 2 || parts[1].trim().isEmpty) {
      return null;
    }
    final remaining = parts[1].trim();
    final monthlyTotal = (parts.length > 4 && parts[4].trim().isNotEmpty)
        ? parts[4].trim()
        : '60';
    return BdCiechiQuota(remaining: remaining, monthlyTotal: monthlyTotal);
  }
}
