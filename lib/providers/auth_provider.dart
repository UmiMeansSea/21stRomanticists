import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Auth states the UI reacts to.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Wraps [FirebaseAuth] + [GoogleSignIn] and exposes a clean ChangeNotifier
/// API consumed by the rest of the app via [Provider].
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    // Subscribe to FirebaseAuth stream immediately.
    _sub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn();

  late final dynamic _sub; // StreamSubscription<User?>

  // ─── Public state ──────────────────────────────────────────────────────────

  User? get user => _auth.currentUser;
  bool get isAuthenticated => user != null;
  AuthStatus get status {
    if (_status == AuthStatus.unknown) return AuthStatus.unknown;
    return user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
  }

  AuthStatus _status = AuthStatus.unknown;
  String? _errorMessage;
  bool _loading = false;

  String? get errorMessage => _errorMessage;
  bool get isLoading => _loading;

  // ─── Auth state listener ───────────────────────────────────────────────────

  void _onAuthChanged(User? u) {
    _status =
        u != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    _loading = false;
    notifyListeners();
  }

  // ─── Email / Password ──────────────────────────────────────────────────────

  /// Sign in with email and password. Returns `true` on success.
  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyError(e.code);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Create a new account with email and password. Returns `true` on success.
  Future<bool> createAccount(String email, String password,
      {String? displayName}) async {
    _setLoading(true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      if (displayName != null && displayName.isNotEmpty) {
        await cred.user?.updateDisplayName(displayName.trim());
        await cred.user?.reload();
      }
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyError(e.code);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── Google Sign-In ────────────────────────────────────────────────────────

  /// Opens the Google OAuth picker. Returns `true` on success.
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) {
        // User cancelled.
        _setLoading(false);
        return false;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyError(e.code);
      return false;
    } catch (_) {
      _errorMessage = 'Google sign-in failed. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── Password reset ────────────────────────────────────────────────────────

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyError(e.code);
      return false;
    }
  }

  // ─── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _google.signOut(),
    ]);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Authentication error. Please try again.';
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
