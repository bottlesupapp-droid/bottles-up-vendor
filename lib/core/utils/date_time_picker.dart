import 'package:flutter/material.dart';

/// Picks a date and time. Replaced in tests; in the app it is Flutter's date picker followed by its time picker. Returns the
/// person's own wall-clock time, or null when they cancel either step.
typedef DateTimePicker = Future<DateTime?> Function(BuildContext context, DateTime initial);

Future<DateTime?> pickDateAndTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 730)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
