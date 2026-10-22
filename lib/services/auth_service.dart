import 'package:firebase_auth/firebase_auth.dart';

/// Service gérant les opérations d'authentification utilisateur via Firebase Auth.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// Flux observant les changements d'état d'authentification de l'utilisateur.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Utilisateur actuellement connecté (null si déconnecté).
  User? get currentUser => _auth.currentUser;

  /// Identifiant unique de l'utilisateur connecté.
  String? get currentUserId => _auth.currentUser?.uid;

  /// Connexion par email et mot de passe.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw _getReadableAuthErrorMessage(e);
    } catch (e) {
      throw 'Une erreur inattendue est survenue lors de la connexion.';
    }
  }

  /// Inscription d'un nouvel utilisateur.
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw _getReadableAuthErrorMessage(e);
    } catch (e) {
      throw 'Une erreur inattendue est survenue lors de l\'inscription.';
    }
  }

  /// Déconnexion de l'utilisateur.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Traduit les codes d'erreurs Firebase Auth en messages clairs pour l'utilisateur.
  String _getReadableAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Aucun utilisateur trouvé avec cette adresse email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Identifiants incorrects. Vérifiez votre email et mot de passe.';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cette adresse email.';
      case 'invalid-email':
        return 'Le format de l\'adresse email est invalide.';
      case 'weak-password':
        return 'Le mot de passe doit comporter au moins 6 caractères.';
      case 'network-request-failed':
        return 'Connexion réseau impossible. Vérifiez votre accès Internet.';
      case 'too-many-requests':
        return 'Trop de tentatives infructueuses. Veuillez patienter avant de réessayer.';
      default:
        return e.message ?? 'Une erreur d\'authentification s\'est produite.';
    }
  }
}
