import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchesService {
  final String _keyPrefix = 'sonarpad_recent_searches_';

  Future<List<String>> getRecentSearches(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_keyPrefix$domain');
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addSearch(String domain, String query) async {
    if (query.trim().isEmpty) return;
    final q = query.trim();
    
    final prefs = await SharedPreferences.getInstance();
    final searches = await getRecentSearches(domain);
    
    searches.remove(q);
    searches.insert(0, q);
    
    if (searches.length > 50) {
      searches.removeRange(50, searches.length);
    }
    
    await prefs.setString('$_keyPrefix$domain', jsonEncode(searches));
  }

  Future<void> clearSearches(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$domain');
  }
}
