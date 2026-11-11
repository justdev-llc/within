import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A user-facing auth error. [message] is safe to show on screen as-is.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => 'AuthFailure: $message';
}

enum SignUpOutcome {
  /// The account is ready and the user is signed in.
  signedIn,

  /// Email confirmation is on; the user must tap the link we emailed them.
  confirmEmail,
}

/// The only place the app talks to Supabase Auth, so screens deal in plain
/// results and [AuthFailure] messages rather than Supabase types and errors.
///
/// Accounts are optional: when Supabase isn't configured the client is null,
/// [isAvailable] is false and every action fails with a friendly message.
class AuthService {
  AuthService(this._client);

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  User? get currentUser => _client?.auth.currentUser;

  /// Supabase saves the session on the device, so this stays true across
  /// launches until [signOut].
  bool get isSignedIn => currentUser != null;

  /// The name friends will see, captured at sign-up.
  String? get displayName =>
      currentUser?.userMetadata?['display_name'] as String?;

  Stream<AuthState> get authChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();

  Future<SignUpOutcome> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _run(
      () => _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': name.trim()},
      ),
    );
    return response.session == null
        ? SignUpOutcome.confirmEmail
        : SignUpOutcome.signedIn;
  }

  Future<void> signIn({required String email, required String password}) =>
      _run(
        () => _auth.signInWithPassword(email: email.trim(), password: password),
      );

  /// Signs in (or up) with the native Apple sheet. Returns false if the user
  /// closed the sheet, which isn't an error.
  Future<bool> signInWithApple() async {
    final auth = _auth;
    // Apple gets the hash, Supabase the raw value, so Supabase can check the
    // token was minted for this request.
    final rawNonce = auth.generateRawNonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return false;
      debugPrint('Apple sign-in error (${error.code}): ${error.message}');
      throw const AuthFailure('Couldn’t sign in with Apple. Please try again.');
    } on Exception catch (error) {
      debugPrint('Apple sign-in error: $error');
      throw const AuthFailure('Couldn’t sign in with Apple. Please try again.');
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthFailure('Couldn’t sign in with Apple. Please try again.');
    }
    await _run(
      () => auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      ),
    );

    // Apple shares the name only on the very first sign-in, and it isn't in
    // the token, so save it ourselves while we have it.
    final name = [
      credential.givenName,
      credential.familyName,
    ].whereType<String>().join(' ').trim();
    if (name.isNotEmpty && displayName == null) {
      await _run(
        () => auth.updateUser(UserAttributes(data: {'display_name': name})),
      );
    }
    return true;
  }

  Future<void> sendPasswordReset(String email) =>
      _run(() => _auth.resetPasswordForEmail(email.trim()));

  Future<void> signOut() => _run(() => _auth.signOut());

  GoTrueClient get _auth {
    final client = _client;
    if (client == null) {
      throw const AuthFailure('Accounts aren’t available right now.');
    }
    return client.auth;
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailure {
      rethrow;
    } on AuthException catch (error) {
      debugPrint('Auth error (${error.code}): ${error.message}');
      throw AuthFailure(messageFor(error));
    } on Exception catch (error) {
      debugPrint('Auth error: $error');
      throw const AuthFailure('Something went wrong. Please try again.');
    }
  }

  /// Maps Supabase error codes to plain language. The codes are the strings
  /// listed at supabase.com/docs/guides/auth/debugging/error-codes.
  @visibleForTesting
  static String messageFor(AuthException error) {
    if (error is AuthRetryableFetchException) {
      return 'Couldn’t connect. Check your internet connection and try again.';
    }
    return switch (error.code) {
      'invalid_credentials' => 'That email or password doesn’t match.',
      'user_already_exists' || 'email_exists' =>
        'That email is already registered. Try signing in instead.',
      'email_address_invalid' => 'Please enter a valid email address.',
      'weak_password' => 'Please choose a stronger password.',
      'email_not_confirmed' =>
        'Please confirm your email first — check your inbox for the link.',
      'over_email_send_rate_limit' || 'over_request_rate_limit' =>
        'Too many attempts. Please wait a moment and try again.',
      'signup_disabled' => 'New sign-ups are paused right now.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}
