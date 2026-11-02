import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The bottom bar no longer covers the page (see shell_overlap_test.dart), so a page must not pad its bottom to "clear" it: that only leaves a blank strip above the bar. The only pages that need room
// at the bottom are the ones with a floating Add button (56 high, 16 from the edge), and 100 is the most any of them uses. This stops the old habit (120, 140, "+ 80") coming back.
void main() {
  final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  test('no page pads its bottom by 120 or more', () {
    final bad = <String>[];
    final pattern = RegExp(r'fromLTRB\(\s*[\w.() +*]+,\s*[\w.() +*]+,\s*[\w.() +*]+,\s*(\d+)\)');
    for (final f in files) {
      final text = f.readAsStringSync();
      for (final m in pattern.allMatches(text)) {
        if (int.parse(m.group(1)!) >= 120) bad.add('${f.path}: ${m.group(0)}');
      }
    }
    expect(bad, isEmpty, reason: 'a page that pads for the bar leaves a blank strip above it');
  });

  test('no page adds the device bottom padding plus 80 for the bar', () {
    final bad = [
      for (final f in files)
        if (RegExp(r'padding\.bottom\s*\+\s*80').hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(bad, isEmpty);
  });

  test('a page with a floating button keeps room for it at the end of its list', () {
    // Each of these lists ends under the button unless it is padded; 72 is the button (56) and its margin (16).
    const roomFor = {
      'lib/features/events/screens/manage_event_tables_screen.dart': 88,
      'lib/features/events/screens/manage_lineup_screen.dart': 88,
      'lib/features/events/screens/scheduled_releases_screen.dart': 88,
      'lib/features/clubs/screens/clubs_list_screen.dart': 100,
      'lib/features/owner/screens/setup/bottle_menu_editor.dart': 100,
      'lib/features/owner/screens/setup/floors_editor.dart': 100,
      'lib/features/owner/screens/setup/table_types_editor.dart': 100,
    };
    roomFor.forEach((path, px) {
      expect(File(path).readAsStringSync(), contains(', $px)'), reason: '$path should keep $px at the bottom for its Add button');
      expect(px, greaterThanOrEqualTo(72));
    });
  });
}
