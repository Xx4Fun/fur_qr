import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../screens/auth_screen.dart';
import '../screens/main_layout.dart';
import '../config/auth_config.dart';

class SupabaseService {
  SupabaseService._privateConstructor();
  static final SupabaseService instance = SupabaseService._privateConstructor();

  final SupabaseClient client = Supabase.instance.client;
  bool _isGoogleSignInInitialized = false;

  void setupAuthListener(BuildContext context) {
    client.auth.onAuthStateChange.listen((data) {
      if (!context.mounted) return;
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainLayoutScreen()),
        );
      } else if (event == AuthChangeEvent.signedOut) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    if (!_isGoogleSignInInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: AuthConfig.googleWebClientId,
      );
      _isGoogleSignInInitialized = true;
    }
    
    final googleUser = await GoogleSignIn.instance.authenticate();
    
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw 'Failed to retrieve Google ID Token';
    }

    String? accessToken;
    try {
      final scopes = ['email', 'profile', 'openid'];
      final authClient = googleUser.authorizationClient;
      final authorization = await authClient.authorizationForScopes(scopes)
          ?? await authClient.authorizeScopes(scopes);
      accessToken = authorization.accessToken;
    } catch (e) {
      debugPrint('Error getting Google access token: $e');
    }

    await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signUp(String email, String password, String fullName, String phone) async {
    await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone_number': phone,
      }
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }
}