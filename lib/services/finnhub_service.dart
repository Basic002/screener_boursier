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

/// Service gérant les interactions avec l'API Finnhub.
class FinnhubService {
  final http.Client _client;

  FinnhubService({http.Client? client}) : _client = client ?? http.Client();

  /// Récupère la cotation en temps réel d'un symbole boursier.
  Future<StockQuote> fetchQuote(String rawSymbol) async {
    final symbol = rawSymbol.trim().toUpperCase();
    if (symbol.isEmpty) {
      throw const FinnhubException('Veuillez renseigner un symbole boursier.');
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

    debugPrint('[FinnhubService] Requête pour $symbol: $uri');

    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw const FinnhubException(
            'Délai d\'attente dépassé (timeout). Vérifiez votre connexion.',
          );
        },
      );

      debugPrint('[FinnhubService] Réponse pour $symbol -> Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        debugPrint('[FinnhubService] Données $symbol: $decoded');

        if (decoded is! Map<String, dynamic>) {
          throw const FinnhubException('Format de réponse invalide.');
        }

        final quote = StockQuote.fromFinnhubJson(symbol, decoded);

        // Finnhub renvoie c == 0 quand le ticker n'est pas reconnu
        if (!quote.isValid) {
          throw FinnhubException(
            'Symbole "$symbol" introuvable ou aucune cotation disponible.',
          );
        }

        return quote;
      } else if (response.statusCode == 401) {
        throw const FinnhubException(
          'Clé d\'API Finnhub invalide ou non autorisée (401).',
          statusCode: 401,
        );
      } else if (response.statusCode == 429) {
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
      debugPrint('[FinnhubService] Exception réseau: $e');
      throw FinnhubException(
        'Impossible de contacter Finnhub ($e).',
      );
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
      final response = await _client.get(uri).timeout(const Duration(seconds: 6));
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
    } catch (_) {
      // Ignorer pour l'autocomplétion
    }
    return [];
  }
}
