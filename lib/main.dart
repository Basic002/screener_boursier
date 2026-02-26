import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        primaryColor: Colors.green,
        colorScheme: const ColorScheme.dark(primary: Colors.green),
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
  final TextEditingController _controller = TextEditingController();
  List<String> _stocks = [];

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  // Fonction pour CHARGER la mémoire
  Future<void> _loadStocks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stocks = prefs.getStringList('my_stocks') ?? [];
    });
  }

  // Fonction pour SAUVEGARDER en mémoire
  Future<void> _saveStocks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_stocks', _stocks);
  }

  // Fonction pour AJOUTER une action
  void _addStock() {
    final symbol = _controller.text.toUpperCase().trim();
    if (symbol.isNotEmpty && !_stocks.contains(symbol)) {
      setState(() {
        _stocks.add(symbol);
        _saveStocks();
        _controller.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$symbol ajouté à la liste !')));
    }
  }

  // Fonction pour SUPPRIMER une action
  void _removeStock(int index) {
    setState(() {
      _stocks.removeAt(index);
      _saveStocks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📈 Mon Screener Bourse'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Symbole (ex: AAPL, TSLA)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: _addStock,
                ),
              ),
              onSubmitted: (_) =>
                  _addStock(),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _stocks.isEmpty
                  ? const Center(
                      child: Text(
                        "Aucune action suivie pour le moment. Ajoutez-en une !",
                      ),
                    )
                  : ListView.builder(
                      itemCount: _stocks.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.show_chart,
                              color: Colors.green,
                            ),
                            title: Text(
                              _stocks[index],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _removeStock(index),
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
