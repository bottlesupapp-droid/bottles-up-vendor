import 'package:supabase_flutter/supabase_flutter.dart';

/// The text of a failed call: the database's own message for a Postgres error, otherwise whatever the error says.
String messageOf(Object error) =>
    error is PostgrestException ? error.message : error.toString();

/// The database does not have the function: the migration that defines it has not been applied. Nothing the person can fix.
bool isMissingFunction(Object error) =>
    error is PostgrestException &&
    (error.code == '42883' ||
        error.code == 'PGRST202' ||
        error.code == '42P01');

/// The database says this person may not do this (no role for the venue, access ended, signed out).
bool isNoAccess(Object error) => RegExp(
  r'not authori[sz]ed|not allowed|access has ended|signed out|not authenticated',
  caseSensitive: false,
).hasMatch(messageOf(error));

/// A sentence for a failed save or removal. The website's setup functions raise plain sentences ("that arrival time is already
/// added", "this table type has bookings, so it cannot be removed"), which is what a Postgres `raise exception` (code P0001)
/// carries, so those are shown as they are. Anything else (a dropped connection, a constraint) becomes a generic sentence.
String actionMessage(
  Object error, {
  String generic =
      'This could not be saved. Check your connection and try again.',
}) {
  if (isNoAccess(error)) return "You don't have access to do that.";
  if (error is PostgrestException &&
      error.code == 'P0001' &&
      error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  return generic;
}
