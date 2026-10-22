import 'package:flutter/material.dart';
import '../../models/stock_quote.dart';
import '../../services/auth_service.dart';
import '../../services/finnhub_service.dart';
import '../../services/watchlist_service.dart';
import 'widgets/stock_card.dart';

/// Écran principal de la watchlist boursière.
class WatchlistScreen extends StatefulWidget {
  final AuthService? authService;
  final WatchlistService? watchlistService;
  final FinnhubService? finnhubService;

  const WatchlistScreen({
    super.key,
    this.authService,
    this.watchlistService,
    this.finnhubService,
  });

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  late final AuthService _authService;
  late final WatchlistService _watchlistService;
  late final FinnhubService _finnhubService;

  final TextEditingController _symbolController = TextEditingController();

  List<String> _symbols = [];
  final Map<String, StockQuote> _quotes = {};
  final Map<String, String> _errors = {};
  final Set<String> _loadingSymbols = {};

  bool _isInitialLoading = true;
  bool _isAdding = false;

  String? get _userId => _authService.currentUserId;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _watchlistService = widget.watchlistService ?? WatchlistService();
    _finnhubService = widget.finnhubService ?? FinnhubService();

    _loadWatchlist();
  }

  @override
  void dispose() {
    _symbolController.dispose();
    super.dispose();
  }

  /// Charge la liste des symboles depuis Firestore puis interroge Finnhub.
  Future<void> _loadWatchlist() async {
    final uid = _userId;
    if (uid == null) {
      if (mounted) setState(() => _isInitialLoading = false);
      return;
    }

    try {
      final symbols = await _watchlistService.getWatchlist(uid);
      if (!mounted) return;

      setState(() {
        _symbols = symbols;
        _isInitialLoading = false;
      });

      // Rafraîchit les cotations
      await _refreshAllQuotes();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isInitialLoading = false);
      _showErrorSnackBar(e.toString());
    }
  }

  /// Rafraîchit les cours de toutes les actions de la liste.
  Future<void> _refreshAllQuotes() async {
    final futures = _symbols.map((symbol) => _fetchSingleQuote(symbol));
    await Future.wait(futures);
  }

  /// Récupère la cotation d'un symbole unique avec gestion d'erreurs claire.
  Future<void> _fetchSingleQuote(String symbol) async {
    if (!mounted) return;
    setState(() {
      _loadingSymbols.add(symbol);
      _errors.remove(symbol);
    });

    try {
      final quote = await _finnhubService.fetchQuote(symbol);
      if (!mounted) return;

      setState(() {
        _quotes[symbol] = quote;
        _errors.remove(symbol);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errors[symbol] = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSymbols.remove(symbol));
      }
    }
  }

  /// Valide et ajoute un nouveau symbole.
  Future<void> _addSymbol() async {
    final rawInput = _symbolController.text.trim();
    final symbol = rawInput.toUpperCase();

    if (symbol.isEmpty) {
      _showErrorSnackBar('Veuillez entrer un symbole boursier (ex: AAPL, TSLA).');
      return;
    }

    if (_symbols.contains(symbol)) {
      _showErrorSnackBar('Le symbole "$symbol" est déjà dans votre liste.');
      return;
    }

    final uid = _userId;
    if (uid == null) return;

    setState(() => _isAdding = true);
    FocusScope.of(context).unfocus();

    try {
      // 1. Validation du ticker auprès de Finnhub
      final quote = await _finnhubService.fetchQuote(symbol);

      // 2. Sauvegarde Firestore
      await _watchlistService.addSymbol(uid, symbol);

      if (!mounted) return;

      setState(() {
        _symbols.insert(0, symbol);
        _quotes[symbol] = quote;
        _errors.remove(symbol);
        _symbolController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action $symbol ajoutée avec succès !'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  /// Supprime un symbole de la liste et de Firestore.
  Future<void> _removeSymbol(String symbol) async {
    final uid = _userId;
    if (uid == null) return;

    final index = _symbols.indexOf(symbol);
    final previousQuote = _quotes[symbol];

    setState(() {
      _symbols.remove(symbol);
      _quotes.remove(symbol);
      _errors.remove(symbol);
    });

    try {
      await _watchlistService.removeSymbol(uid, symbol);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$symbol retiré de votre suivi.'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () async {
              setState(() {
                _symbols.insert(index, symbol);
                if (previousQuote != null) _quotes[symbol] = previousQuote;
              });
              await _watchlistService.addSymbol(uid, symbol);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _symbols.insert(index, symbol);
        if (previousQuote != null) _quotes[symbol] = previousQuote;
      });
      _showErrorSnackBar('Erreur lors de la suppression : $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.candlestick_chart, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('Stock Alert Pro'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Se déconnecter',
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barre d'ajout de symbole
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _symbolController,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      enabled: !_isAdding,
                      decoration: InputDecoration(
                        hintText: 'Ajouter un symbole (ex: AAPL, NVDA, TSLA)...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _addSymbol(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isAdding ? null : _addSymbol,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isAdding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ajouter'),
                  ),
                ],
              ),
            ),

            // Contenu principal
            Expanded(
              child: _isInitialLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _symbols.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _refreshAllQuotes,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _symbols.length,
                            padding: const EdgeInsets.only(top: 8, bottom: 24),
                            itemBuilder: (context, index) {
                              final symbol = _symbols[index];
                              final quote = _quotes[symbol];
                              final isLoading = _loadingSymbols.contains(symbol);
                              final errorMessage = _errors[symbol];

                              return StockCard(
                                key: ValueKey(symbol),
                                symbol: symbol,
                                quote: quote,
                                isLoading: isLoading,
                                errorMessage: errorMessage,
                                onRetry: () => _fetchSingleQuote(symbol),
                                onDelete: () => _removeSymbol(symbol),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.query_stats,
              size: 80,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            const Text(
              'Votre portefeuille est vide',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez des actions pour suivre leur cotation en temps réel et les synchroniser sur tous vos appareils.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: ['AAPL', 'MSFT', 'NVDA', 'TSLA', 'AMZN', 'GOOGL'].map((s) {
                return ActionChip(
                  label: Text('+ $s'),
                  onPressed: () {
                    _symbolController.text = s;
                    _addSymbol();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
