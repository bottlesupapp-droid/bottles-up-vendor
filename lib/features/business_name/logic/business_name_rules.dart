import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';

/// The rules for a business's name, the same ones the database enforces in `rename_business` (the database has the last word: this is so the person is told before the call, in the box).

const int businessNameMin = 2;
const int businessNameMax = 80;

/// How many days must pass between two real renames. A change of capitals or spacing only is a typo fix and is always allowed.
const int businessNameGapDays = 30;

/// Only the business's own owner (a venue business) or organizer (an event business) may rename it: the one person who made it. Managers, door staff and the rest may not.
bool canRenameBusiness(Workspace workspace) =>
    workspace.role == WorkspaceRole.owner ||
    workspace.role == WorkspaceRole.organizer;

/// The name as it will be saved: spaces at the ends removed, runs of spaces made one.
String tidyBusinessName(String raw) =>
    raw.replaceAll(RegExp(r'\s+'), ' ').trim();

final RegExp _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

/// What is wrong with [raw] as a new name for a business that is called [current], in a sentence for the person; null when it is fine to try.
String? businessNameProblem(String raw, {required String current}) {
  if (_controlCharacters.hasMatch(raw)) {
    return 'The business name has characters that are not allowed.';
  }
  final name = tidyBusinessName(raw);
  if (name.length < businessNameMin) {
    return 'The business name must be at least $businessNameMin characters.';
  }
  if (name.length > businessNameMax) {
    return 'The business name can be at most $businessNameMax characters.';
  }
  if (name == current) return 'That is already the name of this business.';
  return null;
}

/// The database's refusals are plain sentences that start in lower case ("another business already uses that name. Choose a different one"): shown as a sentence.
String asSentence(String text) {
  final t = text.trim();
  if (t.isEmpty) return t;
  final first = t[0].toUpperCase() + t.substring(1);
  return first.endsWith('.') || first.endsWith('!') || first.endsWith('?')
      ? first
      : '$first.';
}
