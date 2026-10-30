import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/google_sign_in_config.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/utils/plain_error.dart';
import 'social_sign_in_support.dart';

enum SocialProvider {
  google('Google', OAuthProvider.google),
  apple('Apple', OAuthProvider.apple);

  const SocialProvider(this.label, this.oauth);

  final String label;
  final OAuthProvider oauth;
}

/// A sign-in with Google or Apple that did not go through. [message] is a plain sentence for the person; [cancelled] is true when they only closed the Google or Apple sheet, which is not
/// an error to show.
class SocialSignInException implements Exception {
  const SocialSignInException(this.message, {this.cancelled = false});

  final String message;
  final bool cancelled;

  @override
  String toString() => 'SocialSignInException($message)';
}

/// What Google or Apple handed back for Supabase to check. [nonce] is Apple's: the plain value whose hash Apple signed into the token.
class SocialCredential {
  const SocialCredential({required this.idToken, this.accessToken, this.nonce});

  final String idToken;
  final String? accessToken;
  final String? nonce;
}

typedef CredentialSource = Future<SocialCredential> Function(SocialProvider provider);
typedef IdTokenSignIn = Future<AuthResponse> Function(SocialProvider provider, SocialCredential credential);

/// Sign-in with Google or Apple. This app signs people IN: business accounts are made on the website, and it never makes an account or a `vendors` row. Supabase makes an account for any
/// Google or Apple identity it has not seen, so a sign-in that just made one is undone at once (signed out on this phone) and the person is told, unless they came to accept an invitation
/// ([allowNewAccount]). The three outside pieces are replaced in tests.
class SocialSignInService {
  SocialSignInService({CredentialSource? credentials, IdTokenSignIn? signInWithToken, Future<void> Function()? signOutLocally})
      : _credentials = credentials ?? _fromPlugin,
        _signInWithToken = signInWithToken ?? _supabaseSignIn,
        _signOutLocally = signOutLocally ?? _supabaseSignOut;

  final CredentialSource _credentials;
  final IdTokenSignIn _signInWithToken;
  final Future<void> Function() _signOutLocally;

  /// Throws [SocialSignInException]. On return the person is signed in to an account that already existed (or [allowNewAccount] was set).
  Future<void> signIn(SocialProvider provider, {bool allowNewAccount = false}) async {
    final credential = await _credentials(provider);

    final AuthResponse response;
    try {
      response = await _signInWithToken(provider, credential);
    } on AuthException catch (e) {
      logProblem('${provider.label} sign-in (Supabase)', e);
      final text = e.message.toLowerCase();
      if (text.contains('audience') || text.contains('nonce') || text.contains('provider') || text.contains('not enabled')) {
        throw SocialSignInException('${provider.label} sign-in is not set up for this app yet. Please contact support.');
      }
      throw SocialSignInException('We could not sign you in with ${provider.label}. Please try again.');
    } catch (e) {
      logProblem('${provider.label} sign-in (Supabase)', e);
      throw SocialSignInException('We could not sign you in with ${provider.label}. Check your connection and try again.');
    }

    final user = response.user;
    if (user == null) {
      throw SocialSignInException('We could not sign you in with ${provider.label}. Please try again.');
    }

    if (!allowNewAccount && accountJustCreated(user)) {
      try {
        await _signOutLocally();
      } catch (e) {
        logProblem('sign out of a ${provider.label} sign-in that made a new account', e);
      }
      throw SocialSignInException(
        'No BottlesUp Business account was found for this ${provider.label} sign-in. Accounts are created on our website: create yours there, or sign in with the e-mail you signed up with.',
      );
    }
  }

  // signInWithIdToken is marked experimental by the Supabase package, but it is the documented way to sign in with the token a native Google or Apple sheet returns.
  static Future<AuthResponse> _supabaseSignIn(SocialProvider provider, SocialCredential credential) => SupabaseConfig.auth
      // ignore: experimental_member_use
      .signInWithIdToken(provider: provider.oauth, idToken: credential.idToken, accessToken: credential.accessToken, nonce: credential.nonce)
      .timeout(const Duration(seconds: 30));

  static Future<void> _supabaseSignOut() => SupabaseConfig.auth.signOut(scope: SignOutScope.local);

  static Future<SocialCredential> _fromPlugin(SocialProvider provider) => provider == SocialProvider.google ? _google() : _apple();

  static Future<SocialCredential> _google() async {
    final platform = defaultTargetPlatform;
    if (!GoogleSignInConfig.isConfiguredFor(platform)) {
      throw const SocialSignInException('Google sign-in is not available in this version of the app yet.');
    }
    final google = GoogleSignIn(
      clientId: platform == TargetPlatform.iOS ? GoogleSignInConfig.iosClientId : null,
      serverClientId: GoogleSignInConfig.webClientId,
      scopes: const ['email', 'profile', 'openid'],
    );
    try {
      // Forget the last Google account so the list of accounts shows every time.
      await google.signOut();
    } catch (_) {}

    final GoogleSignInAccount? account;
    try {
      account = await google.signIn().timeout(const Duration(seconds: 60));
    } on PlatformException catch (e) {
      logProblem('Google sign-in sheet', e);
      if (e.code == GoogleSignIn.kSignInCanceledError) {
        throw const SocialSignInException('Google sign-in was cancelled', cancelled: true);
      }
      if (e.code == GoogleSignIn.kNetworkError) {
        throw const SocialSignInException('Network error. Please check your internet connection and try again.');
      }
      final detail = '${e.message}';
      if (detail.contains('ApiException: 10') || detail.contains('12500')) {
        throw const SocialSignInException('Google sign-in is not set up for this app yet. Please contact support.');
      }
      throw const SocialSignInException('Google sign-in failed. Please try again.');
    } on TimeoutException {
      throw const SocialSignInException('Google sign-in timed out. Please try again.');
    }
    if (account == null) throw const SocialSignInException('Google sign-in was cancelled', cancelled: true);

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw const SocialSignInException('We could not get your Google details. Please try again.');
    return SocialCredential(idToken: idToken, accessToken: auth.accessToken);
  }

  static Future<SocialCredential> _apple() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw const SocialSignInException('Apple sign-in is only available on iPhone.');
    }
    // Apple gets the hash of this value and puts it in the token; Supabase gets the plain value and checks it.
    final rawNonce = newNonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(scopes: const [AppleIDAuthorizationScopes.email], nonce: sha256Hex(rawNonce))
          .timeout(const Duration(seconds: 60));
    } on SignInWithAppleAuthorizationException catch (e) {
      logProblem('Apple sign-in sheet', e);
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialSignInException('Apple sign-in was cancelled', cancelled: true);
      }
      if (e.code == AuthorizationErrorCode.notHandled) {
        throw const SocialSignInException('Apple sign-in is not set up for this app yet. Please contact support.');
      }
      throw const SocialSignInException('Apple sign-in failed. Please try again.');
    } on TimeoutException {
      throw const SocialSignInException('Apple sign-in timed out. Please try again.');
    }
    final token = credential.identityToken;
    if (token == null) throw const SocialSignInException('We could not get your Apple details. Please try again.');
    return SocialCredential(idToken: token, nonce: rawNonce);
  }
}
