import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../models/stock_quote.dart';

/// Exception levée lors d'un problème avec l'API Finnhub.
class FinnhubException implements Exception {
  final String message;
  final int? statusCode;

  const FinnhubException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Service gérant les interactions avec l'API Finnhub avec cache en mémoire.
class FinnhubService {
  final http.Client _client;

  /// Cache en mémoire des cotations pour éviter les requêtes superflues.
  final Map<String, StockQuote> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Durée de validité du cache en mémoire (30 secondes).
  static const Duration cacheTtl = Duration(seconds: 30);

  FinnhubService({http.Client? client}) : _client = client ?? http.Client();

  /// Récupère la cotation en temps réel d'un symbole boursier.
  /// Si [forceRefresh] est faux et que les données ont moins de 30 secondes,
  /// la valeur en mémoire est renvoyée instantanément sans appel réseau.
  Future<StockQuote> fetchQuote(String rawSymbol, {bool forceRefresh = false}) async {
    final symbol = rawSymbol.trim().toUpperCase();
    if (symbol.isEmpty) {
      throw const FinnhubException('Veuillez renseigner un symbole boursier.');
    }

    // Vérification du cache mémoire
    if (!forceRefresh && _memoryCache.containsKey(symbol)) {
      final cachedAt = _cacheTimestamps[symbol];
      if (cachedAt != null && DateTime.now().difference(cachedAt) < cacheTtl) {
        return _memoryCache[symbol]!;
      }
    }

    final apiKey = AppConfig.finnhubApiKey;
    if (apiKey.isEmpty || apiKey == 'VOTRE_CLE_FINNHUB_ICI') {
      throw const FinnhubException(
        'Clé d\'API Finnhub non configurée. Vérifiez secrets.dart.',
      );
    }

    final uri = Uri.parse(
      '${AppConfig.finnhubBaseUrl}/quote?symbol=$symbol&token=$apiKey',
    );

    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          throw const FinnhubException(
            'Délai dépassé lors de la connexion à Finnhub.',
          );
        },
      );

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw const FinnhubException('Format de réponse invalide.');
        }

        final quote = StockQuote.fromFinnhubJson(symbol, decoded);

        if (!quote.isValid) {
          throw FinnhubException(
            'Symbole "$symbol" introuvable ou aucune cotation disponible.',
          );
        }

        // Mettre à jour le cache
        _memoryCache[symbol] = quote;
        _cacheTimestamps[symbol] = DateTime.now();

        return quote;
      } else if (response.statusCode == 401) {
        throw const FinnhubException(
          'Clé d\'API Finnhub non autorisée (401).',
          statusCode: 401,
        );
      } else if (response.statusCode == 429) {
        // En cas de rate limit, si on a une ancienne valeur en cache, la retourner
        if (_memoryCache.containsKey(symbol)) {
          return _memoryCache[symbol]!;
        }
        throw const FinnhubException(
          'Limite de requêtes atteinte (60 req/min). Patientez quelques secondes.',
          statusCode: 429,
        );
      } else {
        throw FinnhubException(
          'Erreur serveur (${response.statusCode}) pour $symbol.',
          statusCode: response.statusCode,
        );
      }
    } on FinnhubException {
      rethrow;
    } catch (e) {
      // Si une valeur existe déjà en mémoire, la conserver plutôt que d'échouer
      if (_memoryCache.containsKey(symbol)) {
        return _memoryCache[symbol]!;
      }
      debugPrint('[FinnhubService] Exception réseau: $e');
      throw FinnhubException('Impossible de contacter Finnhub ($e).');
    }
  }

  /// Recherche des symboles d'actions correspondant à une requête.
  Future<List<Map<String, String>>> searchSymbols(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final apiKey = AppConfig.finnhubApiKey;
    final uri = Uri.parse(
      '${AppConfig.finnhubBaseUrl}/search?q=$q&token=$apiKey',
    );

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> results = data['result'] ?? [];
        return results
            .where((item) => item['type'] == 'Common Stock')
            .take(10)
            .map((item) => {
                  'symbol': (item['symbol'] ?? '').toString(),
                  'description': (item['description'] ?? '').toString(),
                })
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
