/// Modèle représentant la cotation financière d'un titre boursier.
class StockQuote {
  final String symbol;
  final double currentPrice;
  final double change;
  final double percentChange;
  final double? highPrice;
  final double? lowPrice;
  final double? openPrice;
  final double? previousClose;
  final DateTime? timestamp;

  const StockQuote({
    required this.symbol,
    required this.currentPrice,
    required this.change,
    required this.percentChange,
    this.highPrice,
    this.lowPrice,
    this.openPrice,
    this.previousClose,
    this.timestamp,
  });

  /// Indique si la variation de prix est positive ou neutre.
  bool get isPositive => change >= 0;

  /// Vérifie si la cotation est valide.
  /// L'API Finnhub renvoie `c: 0` lorsque le symbole n'existe pas.
  bool get isValid => currentPrice > 0;

  /// Construit un objet [StockQuote] à partir de la réponse JSON de Finnhub (`/quote`).
  factory StockQuote.fromFinnhubJson(String symbol, Map<String, dynamic> json) {
    final dynamic rawTimestamp = json['t'];
    DateTime? parsedTimestamp;
    if (rawTimestamp is int && rawTimestamp > 0) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(rawTimestamp * 1000);
    }

    return StockQuote(
      symbol: symbol.trim().toUpperCase(),
      currentPrice: (json['c'] as num?)?.toDouble() ?? 0.0,
      change: (json['d'] as num?)?.toDouble() ?? 0.0,
      percentChange: (json['dp'] as num?)?.toDouble() ?? 0.0,
      highPrice: (json['h'] as num?)?.toDouble(),
      lowPrice: (json['l'] as num?)?.toDouble(),
      openPrice: (json['o'] as num?)?.toDouble(),
      previousClose: (json['pc'] as num?)?.toDouble(),
      timestamp: parsedTimestamp,
    );
  }

  /// Retourne le texte formaté du pourcentage (ex: "+1.25%" ou "-0.80%").
  String get formattedPercent {
    final sign = isPositive ? '+' : '';
    return '$sign${percentChange.toStringAsFixed(2)}%';
  }

  /// Retourne le texte formaté du prix (ex: "185.50 $").
  String get formattedPrice {
    return '${currentPrice.toStringAsFixed(2)} \$';
  }
}
