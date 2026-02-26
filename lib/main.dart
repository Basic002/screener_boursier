import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const StockHomePage();
          } else {
            return const AuthPage();
          }
        },
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLogin = true;

  Future<void> _submit() async {
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Connexion' : 'Inscription')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              child: Text(isLogin ? 'Se connecter' : 'Créer un compte'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  isLogin = !isLogin;
                });
              },
              child: Text(
                isLogin
                    ? "Pas encore de compte ? S'inscrire"
                    : "Déjà un compte ? Se connecter",
              ),
            ),
          ],
        ),
      ),
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

  String get userId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadStocksFromCloud();
  }

  Future<void> _loadStocksFromCloud() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        setState(() {
          _stocks = List<String>.from(doc.data()?['stocks'] ?? []);
        });
        for (String symbol in _stocks) {
          _fetchStockPrice(symbol);
        }
      }
    } catch (e) {
      print("Erreur de chargement Cloud : $e");
    }
  }

  Future<void> _saveStocksToCloud() async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'stocks': _stocks,
      });
    } catch (e) {
      print("Erreur de sauvegarde Cloud : $e");
    }
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
        }
      }
    } catch (e) {
      print("Erreur : $e");
    }
  }

  void _addStock() {
    final symbol = _controller.text.toUpperCase().trim();
    if (symbol.isNotEmpty && !_stocks.contains(symbol)) {
      setState(() {
        _stocks.add(symbol);
        _controller.clear();
      });
      _saveStocksToCloud();
      _fetchStockPrice(symbol);
    }
  }

  void _removeStock(int index) {
    setState(() {
      String symbolToRemove = _stocks[index];
      _stocks.removeAt(index);
      _stockData.remove(symbolToRemove);
    });
    _saveStocksToCloud();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Mon Screener Cloud'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              setState(() {
                _stocks.clear();
                _stockData.clear();
              });
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
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
                      child: Text("Votre portefeuille Cloud est vide !"),
                    )
                  : ListView.builder(
                      itemCount: _stocks.length,
                      itemBuilder: (context, index) {
                        String symbol = _stocks[index];
                        var data = _stockData[symbol];

                        if (data == null) {
                          return Card(
                            child: ListTile(
                              title: Text(symbol),
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
                            subtitle: Text("${data['price']} \$"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${isPositive ? '+' : ''}${data['percent']}%",
                                  style: TextStyle(
                                    color: priceColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
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
