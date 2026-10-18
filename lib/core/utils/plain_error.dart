import 'package:flutter/foundation.dart';

/// Words for a request that did not work, for people (brief 15 Oct, section 33): plain language, what to do next, and never the database's or
/// the network's own text ("Could not find a relationship between...", a stack trace, a table name). The technical reason goes to the log with
/// [logProblem], where whoever looks after the app can read it.

/// A list or page that could not be loaded. Shown with a Retry button, never in place of an empty result ("No venues", zero revenue).
String loadFailedMessage(String what) => 'We could not load $what. Check your connection and try again.';

/// Something the person tried to save. Their entries are still on the screen.
String saveFailedMessage(String what) => 'We could not save $what. Your entries are still here. Try again.';

/// Something the person tried to upload.
String uploadFailedMessage(String what) => 'We could not upload $what. Try again.';

/// Writes the technical reason to the log, with where it happened. Never shown on screen.
void logProblem(String where, Object error) => debugPrint('$where: $error');

/// For use inside a `catch`: logs the technical reason and returns the sentence to show. [what] reads after "We could not", e.g. `create the club`.
String couldNot(String what, Object error) {
  logProblem(what, error);
  return 'We could not $what. Try again.';
}

/// The same for a read that failed. [what] reads after "load", e.g. `your bookings`.
String couldNotLoad(String what, Object error) {
  logProblem('load $what', error);
  return loadFailedMessage(what);
}
