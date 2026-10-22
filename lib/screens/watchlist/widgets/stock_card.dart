import 'package:flutter/material.dart';
import '../../../models/stock_quote.dart';

/// Widget affichant les détails d'une action dans la watchlist.
class StockCard extends StatelessWidget {
  final String symbol;
  final StockQuote? quote;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onDelete;
  final VoidCallback onRetry;

  const StockCard({
    super.key,
    required this.symbol,
    required this.quote,
    required this.isLoading,
    this.errorMessage,
    required this.onDelete,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // 1. État de chargement
    if (isLoading) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.shade800,
            child: const Icon(Icons.show_chart, color: Colors.grey),
          ),
          title: Text(
            symbol,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          subtitle: const Text('Actualisation du cours...'),
          trailing: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // 2. État d'erreur / Données indisponibles (ne tourne plus en boucle !)
    if (quote == null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red.shade900.withValues(alpha: 0.3),
            child: const Icon(Icons.error_outline, color: Colors.orangeAccent),
          ),
          title: Text(
            symbol,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          subtitle: Text(
            errorMessage ?? 'Données indisponibles',
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                tooltip: 'Réessayer',
                onPressed: onRetry,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                tooltip: 'Supprimer',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      );
    }

    // 3. Données de cotation disponibles
    final currentQuote = quote!;
    final isPositive = currentQuote.isPositive;
    final color = isPositive ? Colors.greenAccent.shade400 : Colors.redAccent.shade400;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentQuote.symbol,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentQuote.formattedPrice,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    currentQuote.formattedPercent,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isPositive ? '+' : ''}${currentQuote.change.toStringAsFixed(2)} \$',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              tooltip: 'Supprimer',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
