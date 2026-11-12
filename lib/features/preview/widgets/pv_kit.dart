import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';

/// The building blocks of the sample screens ("Pv" for preview). They are made of the same kit as the real screens (`bu_kit.dart`), so a
/// sample screen looks like the screen will look; what they add is the sample behaviour: every button says "nothing was saved or sent".

/// What a button on a sample screen does.
void pvNotConnected(BuildContext context, [String? message]) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message ?? 'Sample screen: nothing was saved or sent.')));
}

/// Opens a sample page on top of the current one.
Future<T?> pvOpen<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));

/// Set by the mini-app shell, which already says "Sample" in its bar, so its pages do not repeat the note.
class PvMiniAppScope extends InheritedWidget {
  const PvMiniAppScope({super.key, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PvMiniAppScope>() != null;

  @override
  bool updateShouldNotify(PvMiniAppScope oldWidget) => false;
}

/// The one line that says what a sample screen is.
class PvSampleNote extends StatelessWidget {
  const PvSampleNote({super.key});

  static const String text = 'Sample screen: the layout is real, the names and numbers are made up. Nothing here is saved or sent.';

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return BuCard(
      key: const Key('pv-sample-note'),
      padding: const EdgeInsets.symmetric(horizontal: BuSpace.m, vertical: BuSpace.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Ionicons.flask_outline, size: 18, color: bu.amber),
          const SizedBox(width: BuSpace.s + 2),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: bu.muted))),
        ],
      ),
    );
  }
}

/// A page of a sample screen: the heading, the note, then the content.
class PvPage extends StatelessWidget {
  const PvPage({super.key, required this.title, this.eyebrow, this.intro, this.trailing, required this.children, this.showNote = true});

  final String title;
  final String? eyebrow;
  final String? intro;
  final Widget? trailing;
  final List<Widget> children;
  final bool showNote;

  @override
  Widget build(BuildContext context) {
    final note = showNote && !PvMiniAppScope.of(context);
    return ListView(
      key: const Key('pv-page'),
      padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, BuSpace.xxl + BuSpace.xl),
      children: [
        BuPageHeader(eyebrow: eyebrow, title: title, intro: intro, trailing: trailing),
        if (note) ...[const SizedBox(height: BuSpace.l), const PvSampleNote()],
        const SizedBox(height: BuSpace.l),
        ...children,
      ],
    );
  }
}

/// A sample page that is opened on its own (from the list of sample screens, or from a row of another sample page): a bar with a Back
/// button, then the page.
class PvStandalone extends StatelessWidget {
  const PvStandalone({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: child),
    );
  }
}

class PvStat {
  const PvStat(this.value, this.label, {this.hint, this.color});

  final String value;
  final String label;
  final String? hint;
  final Color? color;
}

/// Stat tiles, two to a row.
class PvStatGrid extends StatelessWidget {
  const PvStatGrid(this.stats, {super.key});

  final List<PvStat> stats;

  @override
  Widget build(BuildContext context) {
    Widget tile(PvStat s) => Expanded(child: BuMetricTile(value: s.value, label: s.label, hint: s.hint, valueColor: s.color));
    return Column(
      children: [
        for (var i = 0; i < stats.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: BuSpace.m),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tile(stats[i]),
                  const SizedBox(width: BuSpace.m),
                  if (i + 1 < stats.length) tile(stats[i + 1]) else const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A titled block of a page.
class PvSection extends StatelessWidget {
  const PvSection({super.key, required this.title, this.eyebrow, required this.children, this.actionLabel, this.onAction});

  final String title;
  final String? eyebrow;
  final List<Widget> children;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BuSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BuSectionHeader(title: title, eyebrow: eyebrow, actionLabel: actionLabel, onAction: onAction),
          const SizedBox(height: BuSpace.m),
          ...children,
        ],
      ),
    );
  }
}

class PvRowData {
  const PvRowData(this.title, {this.subtitle, this.icon, this.initials, this.pill, this.tone = BuTone.neutral, this.badge, this.onTap, this.chevron = true});

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Letters in a round tile instead of an icon.
  final String? initials;
  final String? pill;
  final BuTone tone;
  final int? badge;

  /// Defaults to "sample screen" feedback. Pass a function to open another sample page.
  final void Function(BuildContext context)? onTap;
  final bool chevron;
}

class PvAvatar extends StatelessWidget {
  const PvAvatar(this.initials, {super.key, this.size = 40});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bu.panel2, shape: BoxShape.circle, border: Border.all(color: bu.line)),
      child: Text(initials.toUpperCase(), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: bu.soft, fontWeight: FontWeight.w700)),
    );
  }
}

/// A grouped list of rows.
class PvList extends StatelessWidget {
  const PvList(this.rows, {super.key});

  final List<PvRowData> rows;

  @override
  Widget build(BuildContext context) {
    return BuListCard(
      children: [
        for (final r in rows)
          BuListRow(
            title: r.title,
            subtitle: r.subtitle,
            icon: r.initials == null ? r.icon : null,
            leading: r.initials == null ? null : PvAvatar(r.initials!),
            trailing: r.pill != null
                ? BuStatusPill(r.pill!, tone: r.tone)
                : (r.badge != null ? BuCountBadge(r.badge!) : null),
            showChevron: r.chevron,
            onTap: r.chevron ? () => (r.onTap ?? pvNotConnected)(context) : null,
          ),
      ],
    );
  }
}

/// Label and value lines in one card.
class PvLines extends StatelessWidget {
  const PvLines(this.rows, {super.key, this.strongLast = false});

  final List<(String, String)> rows;

  /// Makes the last line (a total) stand out.
  final bool strongLast;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return BuCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: bu.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BuSpace.l, vertical: BuSpace.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: Text(rows[i].$1, style: text.bodyMedium?.copyWith(color: bu.muted))),
                  const SizedBox(width: BuSpace.m),
                  Expanded(
                    flex: 5,
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.end,
                      style: text.bodyMedium?.copyWith(
                        color: strongLast && i == rows.length - 1 ? bu.ink : bu.soft,
                        fontWeight: strongLast && i == rows.length - 1 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PvPrimary extends StatelessWidget {
  const PvPrimary(this.label, {super.key, this.icon, this.onPressed});

  final String label;
  final IconData? icon;
  final void Function(BuildContext context)? onPressed;

  @override
  Widget build(BuildContext context) {
    void press() => (onPressed ?? pvNotConnected)(context);
    return SizedBox(
      width: double.infinity,
      child: icon == null ? FilledButton(onPressed: press, child: Text(label)) : FilledButton.icon(onPressed: press, icon: Icon(icon, size: 18), label: Text(label)),
    );
  }
}

class PvSecondary extends StatelessWidget {
  const PvSecondary(this.label, {super.key, this.icon, this.onPressed});

  final String label;
  final IconData? icon;
  final void Function(BuildContext context)? onPressed;

  @override
  Widget build(BuildContext context) {
    void press() => (onPressed ?? pvNotConnected)(context);
    return SizedBox(
      width: double.infinity,
      child: icon == null ? OutlinedButton(onPressed: press, child: Text(label)) : OutlinedButton.icon(onPressed: press, icon: Icon(icon, size: 18), label: Text(label)),
    );
  }
}

/// Two actions side by side: the secondary one, then the primary one.
class PvDualActions extends StatelessWidget {
  const PvDualActions({super.key, required this.secondary, required this.primary, this.secondaryIcon, this.primaryIcon});

  final String secondary;
  final String primary;
  final IconData? secondaryIcon;
  final IconData? primaryIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: PvSecondary(secondary, icon: secondaryIcon)),
        const SizedBox(width: BuSpace.m),
        Expanded(child: PvPrimary(primary, icon: primaryIcon)),
      ],
    );
  }
}

/// One choice out of a few ("New", "Awaiting client", ...), with an optional count on each.
class PvFilterChips extends StatefulWidget {
  const PvFilterChips({super.key, required this.labels, this.counts = const {}, this.initial, this.onChanged});

  final List<String> labels;
  final Map<String, int> counts;
  final String? initial;
  final ValueChanged<String>? onChanged;

  @override
  State<PvFilterChips> createState() => _PvFilterChipsState();
}

class _PvFilterChipsState extends State<PvFilterChips> {
  late String _selected = widget.initial ?? widget.labels.first;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final label in widget.labels)
            Padding(
              padding: const EdgeInsets.only(right: BuSpace.s),
              child: ChoiceChip(
                key: Key('pv-chip-$label'),
                label: Text((widget.counts[label] ?? 0) > 0 ? '$label · ${widget.counts[label]}' : label),
                selected: _selected == label,
                selectedColor: bu.orangeWash,
                onSelected: (_) {
                  setState(() => _selected = label);
                  widget.onChanged?.call(label);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// A switch with a title and a line under it, in a card.
class PvSwitchCard extends StatefulWidget {
  const PvSwitchCard({super.key, required this.title, this.subtitle, this.initial = false});

  final String title;
  final String? subtitle;
  final bool initial;

  @override
  State<PvSwitchCard> createState() => _PvSwitchCardState();
}

class _PvSwitchCardState extends State<PvSwitchCard> {
  late bool _on = widget.initial;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return BuCard(
      padding: const EdgeInsets.symmetric(horizontal: BuSpace.l, vertical: BuSpace.s + 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: text.titleSmall?.copyWith(fontSize: 15)),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(widget.subtitle!, style: text.bodySmall?.copyWith(color: bu.muted)),
                ],
              ],
            ),
          ),
          Switch(value: _on, onChanged: (v) => setState(() => _on = v)),
        ],
      ),
    );
  }
}

/// A text box with a made-up value in it.
class PvField extends StatelessWidget {
  const PvField(this.label, {super.key, this.value = '', this.maxLines = 1, this.hint, this.suffix});

  final String label;
  final String value;
  final int maxLines;
  final String? hint;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BuSpace.m),
      child: TextFormField(
        initialValue: value,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hint, suffixIcon: suffix),
      ),
    );
  }
}

/// A card that says there is nothing here, and what will appear.
class PvEmpty extends StatelessWidget {
  const PvEmpty({super.key, required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final theme = Theme.of(context).textTheme;
    return BuCard(
      padding: const EdgeInsets.all(BuSpace.xl),
      child: Column(
        children: [
          BuIconTile(icon: icon, size: 52, color: bu.muted, background: bu.panel2),
          const SizedBox(height: BuSpace.m),
          Text(title, textAlign: TextAlign.center, style: theme.titleMedium),
          const SizedBox(height: BuSpace.xs),
          Text(text, textAlign: TextAlign.center, style: theme.bodyMedium?.copyWith(color: bu.muted)),
        ],
      ),
    );
  }
}

/// A small bar chart: made-up values with a label under each bar.
class PvBars extends StatelessWidget {
  const PvBars({super.key, required this.values, required this.labels, this.caption});

  final List<double> values;
  final List<String> labels;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final top = values.fold<double>(1, (m, v) => v > m ? v : m);
    return BuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(values[i] % 1 == 0 ? '${values[i].toInt()}' : '${values[i]}', style: text.labelSmall?.copyWith(color: bu.soft)),
                        const SizedBox(height: 4),
                        Container(
                          height: 90 * (values[i] / top),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(color: bu.orange, borderRadius: BorderRadius.circular(6)),
                        ),
                        const SizedBox(height: 6),
                        Text(labels[i], style: text.labelSmall?.copyWith(color: bu.muted)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: BuSpace.m),
            Text(caption!, style: text.bodySmall?.copyWith(color: bu.muted)),
          ],
        ],
      ),
    );
  }
}

enum PvDayMark { booked, held, request, blocked }

/// A month of days with marks on some of them. The month is a made-up one: the weekday the 1st falls on and the number of days are given.
class PvCalendar extends StatefulWidget {
  const PvCalendar({super.key, required this.monthLabel, required this.startWeekday, required this.days, this.marks = const {}, this.onDayTap});

  final String monthLabel;

  /// 0 is Sunday.
  final int startWeekday;
  final int days;
  final Map<int, PvDayMark> marks;
  final void Function(int day)? onDayTap;

  @override
  State<PvCalendar> createState() => _PvCalendarState();
}

class _PvCalendarState extends State<PvCalendar> {
  int? _selected;

  Color _color(BuTokens bu, PvDayMark m) => switch (m) {
        PvDayMark.booked => bu.green,
        PvDayMark.held => bu.orangeSoft,
        PvDayMark.request => bu.amber,
        PvDayMark.blocked => bu.muted,
      };

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    const week = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final cells = <Widget>[
      for (final d in week) Center(child: Text(d, style: text.labelSmall?.copyWith(color: bu.muted))),
      for (var i = 0; i < widget.startWeekday; i++) const SizedBox.shrink(),
      for (var day = 1; day <= widget.days; day++) _cell(context, bu, text, day),
    ];
    return BuCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(Ionicons.chevron_back, size: 18, color: bu.muted),
              Expanded(child: Center(child: Text(widget.monthLabel, style: text.titleSmall))),
              Icon(Ionicons.chevron_forward, size: 18, color: bu.muted),
            ],
          ),
          const SizedBox(height: BuSpace.m),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: cells,
          ),
          const SizedBox(height: BuSpace.m),
          Wrap(
            spacing: BuSpace.l,
            runSpacing: BuSpace.s,
            children: [
              for (final entry in const {PvDayMark.booked: 'Booked', PvDayMark.held: 'Held', PvDayMark.request: 'Request', PvDayMark.blocked: 'Blocked'}.entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: _color(bu, entry.key), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(entry.value, style: text.labelSmall?.copyWith(color: bu.muted)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, BuTokens bu, TextTheme text, int day) {
    final mark = widget.marks[day];
    final selected = _selected == day;
    final color = mark == null ? null : _color(bu, mark);
    return InkWell(
      key: Key('pv-day-$day'),
      borderRadius: BorderRadius.circular(BuRadius.tile),
      onTap: () {
        setState(() => _selected = day);
        widget.onDayTap?.call(day);
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color?.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(BuRadius.tile),
          border: Border.all(color: selected ? bu.orange : (color?.withValues(alpha: 0.5) ?? Colors.transparent)),
        ),
        child: Text(
          '$day',
          style: text.bodyMedium?.copyWith(
            color: color ?? bu.soft,
            decoration: mark == PvDayMark.blocked ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}

/// A sheet that rises from the bottom, with an eyebrow, a title and anything inside.
Future<void> showPvSheet(BuildContext context, {required String title, String? eyebrow, required Widget child}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, BuSpace.xl + MediaQuery.of(sheetContext).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[BuEyebrow(eyebrow), const SizedBox(height: 6)],
          Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: BuSpace.l),
          child,
        ],
      ),
    ),
  );
}

/// A line of explanation under a block, in the muted colour.
class PvNote extends StatelessWidget {
  const PvNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: BuSpace.s, bottom: BuSpace.l),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.bu.muted)),
    );
  }
}

/// A big money figure with a line under it, in the hero card.
class PvHero extends StatelessWidget {
  const PvHero({super.key, required this.eyebrow, required this.title, this.subtitle, this.trailing});

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => BuHeroCard(eyebrow: eyebrow, title: title, subtitle: subtitle, trailing: trailing);
}

/// Spacing between blocks of a page.
const SizedBox pvGap = SizedBox(height: BuSpace.l);

/// A stand-in for a QR code: a square of dark and light modules (always the same pattern) with the three corner marks. It is not a real code.
class PvQr extends StatelessWidget {
  const PvQr({super.key, this.size = 148});

  final double size;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return Semantics(
      label: 'Sample QR code',
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bu.ink, borderRadius: BorderRadius.circular(BuRadius.tile)),
        child: CustomPaint(painter: _QrPainter(bu.bg)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 21;
    final cell = size.width / n;
    final paint = Paint()..color = color;
    bool inFinder(int x, int y) => (x < 7 && y < 7) || (x >= n - 7 && y < 7) || (x < 7 && y >= n - 7);
    void finder(int ox, int oy) {
      canvas.drawRect(Rect.fromLTWH(ox * cell, oy * cell, 7 * cell, 7 * cell), paint);
      canvas.drawRect(Rect.fromLTWH((ox + 1) * cell, (oy + 1) * cell, 5 * cell, 5 * cell), Paint()..color = Colors.white);
      canvas.drawRect(Rect.fromLTWH((ox + 2) * cell, (oy + 2) * cell, 3 * cell, 3 * cell), paint);
    }

    var seed = 7;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        if (!inFinder(x, y) && (seed >> 8) % 3 == 0) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        }
      }
    }
    finder(0, 0);
    finder(n - 7, 0);
    finder(0, n - 7);
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.color != color;
}
