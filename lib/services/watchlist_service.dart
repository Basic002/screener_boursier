import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service gérant la synchronisation de la watchlist utilisateur avec Cloud Firestore.
class WatchlistService {
  final FirebaseFirestore _firestore;

  WatchlistService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  /// Récupère la liste des symboles suivis par l'utilisateur.
  Future<List<String>> getWatchlist(String userId) async {
    try {
      final doc = await _userDoc(userId).get().timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          debugPrint('[WatchlistService] Timeout lors du chargement de la watchlist.');
          throw 'Délai dépassé lors de la connexion à la base de données.';
        },
      );
      if (doc.exists && doc.data() != null) {
        final List<dynamic>? rawList = doc.data()!['stocks'];
        if (rawList != null) {
          return rawList.map((e) => e.toString().toUpperCase()).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[WatchlistService] Erreur getWatchlist: $e');
      return [];
    }
  }

  /// Ajoute un symbole de façon atomique à la liste de l'utilisateur.
  Future<void> addSymbol(String userId, String symbol) async {
    final cleanSymbol = symbol.trim().toUpperCase();
    try {
      await _userDoc(userId).set({
        'stocks': FieldValue.arrayUnion([cleanSymbol]),
      }, SetOptions(merge: true)).timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          debugPrint('[WatchlistService] Timeout lors de la sauvegarde Firestore.');
        },
      );
    } catch (e) {
      debugPrint('[WatchlistService] Erreur addSymbol: $e');
      // On ne bloque pas l'UI si Firestore est lent ou temporairement inaccessible
    }
  }

  /// Retire un symbole de la liste Firestore.
  Future<void> removeSymbol(String userId, String symbol) async {
    final cleanSymbol = symbol.trim().toUpperCase();
    try {
      await _userDoc(userId).update({
        'stocks': FieldValue.arrayRemove([cleanSymbol]),
      }).timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          debugPrint('[WatchlistService] Timeout lors de la suppression Firestore.');
        },
      );
    } catch (e) {
      debugPrint('[WatchlistService] Erreur removeSymbol: $e');
    }
  }
}
