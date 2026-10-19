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
///
/// Only the database's own short refusals count ("not allowed", "not authorized", "not authenticated" as the WHOLE message, which is what every
/// permission check in the website's functions raises), or the access-ended and signed-out texts. A longer sentence that merely contains those words, such
/// as "the club has not allowed door staff for this event", is a reason to show as it is, not a lack of access.
bool isNoAccess(Object error) => RegExp(
  r'^\s*(not authori[sz]ed|not allowed|not authenticated)\s*\.?\s*$|access has ended|signed out',
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
