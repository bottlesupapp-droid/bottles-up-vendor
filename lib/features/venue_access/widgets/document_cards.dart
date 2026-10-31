import 'package:flutter/material.dart';

import '../../night/logic/night_rules.dart' show ReportSection;

/// A report's sections as cards, the same words as the PDF made from them.
class DocumentCards extends StatelessWidget {
  const DocumentCards({super.key, required this.sections, this.keyPrefix = 'doc-section'});

  final List<ReportSection> sections;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final (i, s) in sections.indexed)
          Card(
            key: Key('$keyPrefix-$i'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  for (final row in s.rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(row.label, style: row.strong ? const TextStyle(fontWeight: FontWeight.w700) : null)),
                          const SizedBox(width: 8),
                          Flexible(child: Text(row.value, textAlign: TextAlign.end, style: row.strong ? const TextStyle(fontWeight: FontWeight.w700) : null)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
