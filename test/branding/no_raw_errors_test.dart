import 'dart:io';

import 'package:bottles_up_vendor/core/utils/error_handler.dart';
import 'package:bottles_up_vendor/core/utils/plain_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Brief 15 Oct, section 33: "Do not display technical database text to users." A failed request is said in plain words, with Retry, and the
/// reason goes to the log. This keeps a raw `$e` / `$error` / `error.toString()` from being put on a screen again.
void main() {
  test('no screen puts a raw error into a Text, SnackBar or message', () {
    // `$e`, `${e}`, `$error`, `${e.message}`, `e.toString()` inside a Text(...). (`${e.subtitle}` of some other thing named e is fine.)
    final raw = RegExp(r"Text\([^;]*(\$e(?![A-Za-z0-9_.])|\$\{e\}|\$\{e\.message\}|\$(error|exception|err)(?![A-Za-z0-9_])|\$\{(error|exception|err)\}|\b(e|error|exception)\.toString\(\))");
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      var n = 0;
      for (final line in f.readAsLinesSync()) {
        n++;
        final code = line.trimLeft();
        if (code.startsWith('//')) continue;
        if (raw.hasMatch(line)) offenders.add('${f.path}:$n  ${code.length > 90 ? code.substring(0, 90) : code}');
      }
    }
    expect(offenders, isEmpty, reason: 'say it in plain words (core/utils/plain_error.dart) and log the reason:\n${offenders.join('\n')}');
  });

  group('the sentences', () {
    test('say what failed and what to do, without a technical word', () {
      for (final s in [loadFailedMessage('your bookings'), saveFailedMessage('the table'), uploadFailedMessage('the photo'), couldNot('create the club', StateError('x')), couldNotLoad('this event', StateError('x'))]) {
        expect(s, startsWith('We could not'));
        expect(s.toLowerCase(), isNot(anyOf(contains('exception'), contains('postgrest'), contains('relation'), contains('sql'), contains('null'))));
      }
      expect(loadFailedMessage('your bookings'), 'We could not load your bookings. Check your connection and try again.');
      expect(saveFailedMessage('the table'), contains('Your entries are still here'));
    });

    test('the reason is never in the sentence', () {
      final reason = StateError('Could not find a relationship between inquiries and events (PGRST200)');
      expect(couldNot('send the proposal', reason), isNot(contains('PGRST200')));
      expect(couldNotLoad('your analytics', reason), isNot(contains('relationship')));
    });
  });

  group('the old error handler no longer passes the database\'s own words through', () {
    test('an unknown database error becomes a plain sentence', () {
      final e = PostgrestException(message: 'Could not find a relationship between \'inquiries\' and \'events\' in the schema cache', code: 'PGRST200');
      final s = ErrorHandler.getErrorMessage(e);
      expect(s, isNot(contains('relationship')));
      expect(s, isNot(contains('schema cache')));
    });

    test('known cases keep their useful wording', () {
      expect(ErrorHandler.getErrorMessage(PostgrestException(message: 'x', code: '23505')), 'This record already exists.');
      expect(ErrorHandler.getErrorMessage(PostgrestException(message: 'x', code: '42501')), contains('permission'));
    });

    test('a storage error is plain too', () {
      expect(ErrorHandler.getErrorMessage(const StorageException('bucket_id xyz violates policy')), isNot(contains('bucket_id')));
    });
  });
}
