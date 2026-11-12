import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The redesign replaced Material's own green, red, orange, blue and grey with the design's colours (`BuTokens`, `context.bu`), so the app has one palette. This keeps them from
/// coming back: a screen that needs a status colour takes it from the tokens. (The floor map's five table states are the one exception, below.)
void main() {
  final features = Directory('lib/features');

  Iterable<File> dartFiles() => features.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  // Material's named hues, with an optional shade: Colors.green, Colors.red[400], Colors.orange.shade700. (Colors.white, black and transparent are not hues.)
  final namedHue = RegExp(r'\bColors\.(green|red|orange|amber|blue|grey|purple|teal|pink|indigo)(?:\.shade\d{2,3}|\[\d{2,3}\])?(?![A-Za-z0-9])');
  // The Material 400-level hexes the app used to write out by hand, and the old brand orange.
  final oldHex = RegExp(r'Color\(0xFF(?:FFB300|66BB6A|EF5350|9E9E9E|42A5F5|AB47BC|FF6B35|FFB800)\)');
  // An empty outlined border on an input: the theme draws inputs.
  final heavyBorder = RegExp(r'border:\s*(?:const\s+)?OutlineInputBorder\(\)');

  // Where a hue is still allowed, and why. Keep this short.
  const allowed = <String, String>{
    'table_map/widgets/floor_canvas.dart': 'the five states of a table, drawn over a floor-plan picture: they need five hues that read on any picture, and the design has fewer',
  };

  String relative(File f) => f.path.replaceFirst('lib/features/', '');

  test('no screen writes one of Material\'s hues any more', () {
    final offenders = <String>[];
    for (final f in dartFiles()) {
      if (allowed.containsKey(relative(f))) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (namedHue.hasMatch(lines[i]) || oldHex.hasMatch(lines[i])) offenders.add('${relative(f)}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: 'use BuTokens.dark.<token> (or context.bu) instead:\n${offenders.take(20).join('\n')}');
  });

  test('no input draws the heavy empty outline: the theme styles inputs', () {
    final offenders = <String>[];
    for (final f in dartFiles()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (heavyBorder.hasMatch(lines[i])) offenders.add('${relative(f)}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });

  test('the allowed exceptions are still there (an exception for a file that no longer needs one is removed)', () {
    for (final entry in allowed.entries) {
      final f = File('lib/features/${entry.key}');
      expect(f.existsSync(), isTrue, reason: entry.key);
      final text = f.readAsStringSync();
      expect(namedHue.hasMatch(text) || oldHex.hasMatch(text), isTrue, reason: '${entry.key} has no Material hue left: drop it from the allowed list (${entry.value})');
    }
  });

  test('the scan does catch what it is meant to', () {
    expect(namedHue.hasMatch('color: Colors.green,'), isTrue);
    expect(namedHue.hasMatch('Colors.orange.shade700'), isTrue);
    expect(namedHue.hasMatch('Colors.grey[600]'), isTrue);
    expect(namedHue.hasMatch('Colors.greenAccent'), isFalse);
    expect(namedHue.hasMatch('Colors.white'), isFalse);
    expect(oldHex.hasMatch('const Color(0xFFFFB300)'), isTrue);
    expect(oldHex.hasMatch('Color(0xFF59D7A2)'), isFalse, reason: 'the design\'s own green is not an old hue');
    expect(heavyBorder.hasMatch("InputDecoration(border: OutlineInputBorder())"), isTrue);
    expect(heavyBorder.hasMatch('OutlineInputBorder(borderRadius: BorderRadius.circular(8))'), isFalse);
  });
}
