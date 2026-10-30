import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A random value for one Apple sign-in. Apple puts its hash inside the token it hands back and Supabase checks the plain value against that hash, so a token taken from somewhere else
/// cannot be used to sign in here.
String newNonce([Random? random, int length = 32]) {
  const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
  final r = random ?? Random.secure();
  return List.generate(length, (_) => alphabet[r.nextInt(alphabet.length)]).join();
}

String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

/// The name Apple gives, only the first time a person uses it with an app (later sign-ins carry none). Null when it gave none.
String? appleFullName(String? given, String? family) {
  final name = [given, family].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ');
  return name.isEmpty ? null : name;
}

/// Whether this sign-in just made the account: for a new account the time it was made and the time of the sign-in are the same moment, while an account that already existed (a Google or
/// Apple identity joined to the person's existing e-mail account included) was made long before. When Supabase gives no usable times this says false, so nobody is turned away on a guess.
bool accountJustCreated(User user, {Duration within = const Duration(seconds: 30)}) {
  final created = DateTime.tryParse(user.createdAt);
  final signedIn = user.lastSignInAt == null ? null : DateTime.tryParse(user.lastSignInAt!);
  if (created == null || signedIn == null) return false;
  return signedIn.difference(created).abs() <= within;
}
