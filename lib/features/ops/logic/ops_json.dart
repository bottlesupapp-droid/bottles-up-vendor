/// Reading a row the database sent back. Every reader is forgiving about a missing or odd value (a screen never crashes on a row), and
/// the parsers that use them drop a row they cannot identify.
String? opsStr(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

int opsInt(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

bool opsBool(Map<String, dynamic> m, String key) => m[key] == true;

DateTime? opsTime(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}
