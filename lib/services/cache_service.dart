import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock_quote.dart';

/// Service de cache local haute performance via SharedPreferences.
/// Permet un affichage instantané des cotations (Stale-While-Revalidate).
class CacheService {
  static const String _keyWatchlist = 'cached_watchlist_symbols';
  static const String _keyQuotes = 'cached_watchlist_quotes';

  /// Sauvegarde la liste des symboles en cache local.
  Future<void> saveWatchlist(List<String> symbols) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyWatchlist, symbols);
    } catch (_) {
      // Ignorer les erreurs de cache
    }
  }

  /// Récupère la liste des symboles depuis le cache local (instantané).
  Future<List<String>> getWatchlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_keyWatchlist) ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Sauvegarde les cotations en cache local.
  Future<void> saveQuotes(Map<String, StockQuote> quotes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> serializableMap = {};
      quotes.forEach((symbol, quote) {
        serializableMap[symbol] = quote.toJson();
      });
      await prefs.setString(_keyQuotes, json.encode(serializableMap));
    } catch (_) {
      // Ignorer les erreurs de cache
    }
  }

  /// Récupère l'ensemble des cotations en cache local (instantané).
  Future<Map<String, StockQuote>> getQuotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyQuotes);
      if (raw == null || raw.isEmpty) return {};

      final Map<String, dynamic> decoded = json.decode(raw);
      final Map<String, StockQuote> result = {};
      decoded.forEach((symbol, data) {
        if (data is Map<String, dynamic>) {
          result[symbol] = StockQuote.fromJson(data);
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }
}
