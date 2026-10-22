import 'package:flutter/foundation.dart';
import 'secrets.dart';

/// Configuration globale et gestion des clés d'environnement.
class AppConfig {
  AppConfig._();

  static const String _envApiKey = String.fromEnvironment('FINNHUB_API_KEY');

  /// Récupère la clé Finnhub :
  /// 1. Si passée en argument de build (`--dart-define=FINNHUB_API_KEY=...`)
  /// 2. Sinon, utilise la clé locale [finnhubApiKeyFromSecret] de `secrets.dart`.
  static String get finnhubApiKey {
    if (_envApiKey.isNotEmpty) {
      return _envApiKey;
    }
    return finnhubApiKeyFromSecret;
  }

  /// URL de base de l'API REST Finnhub.
  static const String finnhubBaseUrl = 'https://finnhub.io/api/v1';
}
