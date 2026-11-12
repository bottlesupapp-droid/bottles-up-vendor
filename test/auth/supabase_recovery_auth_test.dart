// The fake network below is built on package:http, which supabase_flutter brings in; this test file is the only place the app itself names it.
// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';

import 'package:bottles_up_vendor/core/config/password_reset_config.dart';
import 'package:bottles_up_vendor/features/auth/services/password_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The real Supabase client, with the network replaced by a recorder: these are the exact requests the reset flow sends to the server.

const hash = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c';

String _b64(Map<String, Object?> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

// A token the client will accept as a session: three dot-separated parts, the middle one holding an expiry far in the future.
final String _jwt = '${_b64({'alg': 'HS256', 'typ': 'JWT'})}.${_b64({'sub': 'u1', 'aud': 'authenticated', 'role': 'authenticated', 'exp': 4102444800})}.sig';

final Map<String, Object?> _user = {'id': 'u1', 'aud': 'authenticated', 'email': 'sam@example.com', 'app_metadata': {}, 'user_metadata': {}, 'created_at': '2026-01-01T00:00:00Z'};

final Map<String, Object?> _session = {'access_token': _jwt, 'token_type': 'bearer', 'expires_in': 3600, 'refresh_token': 'r1', 'user': _user};

class _Memory extends GotrueAsyncStorage {
  final _items = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _items[key];
  @override
  Future<void> setItem({required String key, required String value}) async => _items[key] = value;
  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);
}

class _Sent {
  _Sent(this.method, this.url, this.body, this.authorization);
  final String method;
  final Uri url;
  final Map<String, Object?> body;
  final String? authorization;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sent = <_Sent>[];

  setUpAll(() async {
    final client = MockClient((request) async {
      final raw = request.body;
      sent.add(_Sent(request.method, request.url, raw.isEmpty ? {} : jsonDecode(raw) as Map<String, Object?>, request.headers['authorization']));
      final path = request.url.path;
      final headers = {'content-type': 'application/json'};
      if (path.endsWith('/verify')) return http.Response(jsonEncode(_session), 200, headers: headers);
      if (path.endsWith('/user')) return http.Response(jsonEncode(_user), 200, headers: headers);
      return http.Response('{}', 200, headers: headers);
    });
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      httpClient: client,
      // The app's own flow (the default, PKCE), with storage kept in memory.
      authOptions: FlutterAuthClientOptions(autoRefreshToken: false, localStorage: const EmptyLocalStorage(), pkceAsyncStorage: _Memory()),
    );
  });

  setUp(sent.clear);

  final auth = SupabaseRecoveryAuth();

  test('asking for the email sends the address, with the redirect that tells the email this is BottlesUp Business', () async {
    await auth.sendResetEmail('sam@example.com');
    final request = sent.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/auth/v1/recover');
    expect(request.url.queryParameters['redirect_to'], passwordResetRedirect);
    expect(request.body['email'], 'sam@example.com');
  });

  test('checking the code sends the email, the digits and type recovery, and opens a session', () async {
    await auth.verifyCode(email: 'sam@example.com', code: '483920');
    final request = sent.single;
    expect(request.url.path, '/auth/v1/verify');
    expect(request.body['email'], 'sam@example.com');
    expect(request.body['token'], '483920');
    expect(request.body['type'], 'recovery');
    expect(auth.hasSession, isTrue);
  });

  test('spending a link\'s token sends only the token and type recovery', () async {
    await auth.verifyTokenHash(hash);
    final request = sent.single;
    expect(request.url.path, '/auth/v1/verify');
    expect(request.body['token_hash'], hash);
    expect(request.body['type'], 'recovery');
    expect(request.body.containsKey('email'), isFalse);
    expect(auth.hasSession, isTrue);
  });

  test('setting the password is one PUT of the password, signed in as the reset session', () async {
    await auth.verifyTokenHash(hash);
    sent.clear();
    await auth.setPassword('new-password-1');
    final request = sent.single;
    expect(request.method, 'PUT');
    expect(request.url.path, '/auth/v1/user');
    expect(request.body, {'password': 'new-password-1'});
    expect(request.authorization, 'Bearer $_jwt');
  });

  test('signing out ends the session on this phone only, and nothing is signed out elsewhere', () async {
    await auth.verifyTokenHash(hash);
    expect(auth.hasSession, isTrue);
    sent.clear();
    await auth.signOutHere();
    expect(auth.hasSession, isFalse);
    expect(sent.single.url.path, '/auth/v1/logout');
    expect(sent.single.url.queryParameters['scope'], 'local');
  });
}
