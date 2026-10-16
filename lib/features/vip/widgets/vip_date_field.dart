import 'package:flutter/material.dart';

import '../logic/vip_rules.dart';

/// A date the person picks, which can be left empty when [optional]. Shows the date, or [emptyLabel].
class VipDateField extends StatelessWidget {
  const VipDateField({super.key, required this.label, required this.value, required this.onChanged, this.optional = false, this.emptyLabel = 'Not set'});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool optional;
  final String emptyLabel;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value == null ? emptyLabel : formatVipDate(value), key: Key('${label.toLowerCase().replaceAll(' ', '-')}-value')),
      onTap: () => _pick(context),
      trailing: optional && value != null ? IconButton(tooltip: 'Clear', icon: const Icon(Icons.clear), onPressed: () => onChanged(null)) : const Icon(Icons.calendar_today_outlined, size: 18),
    );
  }
}
