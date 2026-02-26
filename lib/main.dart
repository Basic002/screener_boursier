import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const StockTrackerApp());
}

class StockTrackerApp extends StatelessWidget {
  const StockTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Alert Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        colorScheme: const ColorScheme.dark(primary: Colors.blueAccent),
      ),
      home: const StockHomePage(),
    );
  }
}

class StockHomePage extends StatefulWidget {
  const StockHomePage({super.key});

  @override
  State<StockHomePage> createState() => _StockHomePageState();
}

class _StockHomePageState extends State<StockHomePage> {
  final String apiKey = 'd6g6adpr01qt4931muugd6g6adpr01qt4931muv0';

  final TextEditingController _controller = TextEditingController();
  List<String> _stocks = [];

  Map<String, Map<String, dynamic>> _stockData = {};

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  Future<void> _loadStocks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stocks = prefs.getStringList('my_stocks') ?? [];
    });
    for (String symbol in _stocks) {
      _fetchStockPrice(symbol);
    }
  }

  Future<void> _saveStocks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_stocks', _stocks);
  }

  Future<void> _fetchStockPrice(String symbol) async {
    final url = Uri.parse(
      'https://finnhub.io/api/v1/quote?symbol=$symbol&token=$apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['c'] != 0) {
          setState(() {
            _stockData[symbol] = {
              'price': data['c'],
              'change': data['d'],
              'percent': data['dp'],
            };
          });
        } else {
          _showError("L'action $symbol est introuvable sur le marché.");
          _removeStock(_stocks.indexOf(symbol));
        }
      }
    } catch (e) {
      print("Erreur de connexion pour $symbol");
    }
  }

  void _addStock() {
    final symbol = _controller.text.toUpperCase().trim();
    if (symbol.isNotEmpty && !_stocks.contains(symbol)) {
      setState(() {
        _stocks.add(symbol);
        _saveStocks();
        _controller.clear();
      });
      _fetchStockPrice(symbol);
    }
  }

  void _removeStock(int index) {
    setState(() {
      String symbolToRemove = _stocks[index];
      _stocks.removeAt(index);
      _stockData.remove(symbolToRemove);
      _saveStocks();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Mon Screener Bourse en Direct'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Symbole (ex: AAPL, MSFT, TSLA)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.blueAccent),
                  onPressed: _addStock,
                ),
              ),
              onSubmitted: (_) => _addStock(),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _stocks.isEmpty
                  ? const Center(
                      child: Text(
                        "Ajoutez une action pour voir son prix en direct !",
                      ),
                    )
                  : ListView.builder(
                      itemCount: _stocks.length,
                      itemBuilder: (context, index) {
                        String symbol = _stocks[index];
                        var data = _stockData[symbol];

                        if (data == null) {
                          return Card(
                            child: ListTile(
                              title: Text(
                                symbol,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: const CircularProgressIndicator(),
                            ),
                          );
                        }

                        bool isPositive = data['change'] >= 0;
                        Color priceColor = isPositive
                            ? Colors.greenAccent
                            : Colors.redAccent;
                        IconData trendIcon = isPositive
                            ? Icons.trending_up
                            : Icons.trending_down;

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              trendIcon,
                              color: priceColor,
                              size: 30,
                            ),
                            title: Text(
                              symbol,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Text(
                              "${data['price']} \$",
                              style: const TextStyle(fontSize: 16),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${isPositive ? '+' : ''}${data['percent']}%",
                                  style: TextStyle(
                                    color: priceColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () => _removeStock(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
