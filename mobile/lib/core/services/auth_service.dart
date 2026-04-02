import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AuthService manages Firebase authentication and token persistence.
/// Implements singleton pattern for session state.
class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  AuthService._internal();

  final _firebaseAuth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();
  final _secureStorage = const FlutterSecureStorage();

  // Expose current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Get ID token (for API requests)
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return await user.getIdToken(forceRefresh);
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _firebaseAuth.signInWithCredential(credential);

      // Persist user email locally for offline reference
      if (result.user != null) {
        await _secureStorage.write(
          key: 'user_email',
          value: result.user!.email,
        );
      }

      return result.user;
    } catch (e) {
      throw AuthException('Google sign-in failed: $e', code: 'ERR_GOOGLE_SIGNIN');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
      await _secureStorage.delete(key: 'user_email');
    } catch (e) {
      throw AuthException('Sign-out failed: $e', code: 'ERR_SIGNOUT');
    }
  }

  // Check if user is authenticated
  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  // Get cached email (works offline)
  Future<String?> getCachedEmail() async {
    return await _secureStorage.read(key: 'user_email');
  }

  // Listen to auth state changes
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();
}

class AuthException implements Exception {
  final String message;
  final String code;

  AuthException(this.message, {required this.code});

  @override
  String toString() => '$code: $message';
}
