import 'package:flutter/material.dart';

import '../logic/table_map_rules.dart';

/// What each state looks like on the map. Colour is never the only sign: every box also says its name and counts.
Color colorOfKind(MapKind k) => switch (k) {
      MapKind.available => const Color(0xFF66BB6A),
      MapKind.held => const Color(0xFFFFB300),
      MapKind.booked => const Color(0xFF42A5F5),
      MapKind.occupied => const Color(0xFFAB47BC),
      MapKind.unavailable => const Color(0xFF9E9E9E),
    };

/// One table drawn on a floor: where it sits (percent of the image), what it says and the colour of its state.
class FloorBoxData {
  const FloorBoxData({required this.id, required this.box, required this.label, this.sublabel, required this.color, this.selected = false});

  final String id;
  final PlacedBox box;
  final String label;
  final String? sublabel;
  final Color color;
  final bool selected;
}

/// The key legend under the map.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
        key: const Key('map-legend'),
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final k in MapKind.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: colorOfKind(k), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Text(k.label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
        ],
      );
}

/// A floor plan picture with the tables drawn on it, positioned by percent of the picture exactly like the website's editor and picker. When [onMove] and [onResize]
/// are given a selected table can be dragged and resized; otherwise boxes can only be tapped.
class FloorCanvas extends StatefulWidget {
  const FloorCanvas({
    super.key,
    required this.imageUrl,
    required this.boxes,
    this.onTap,
    this.onMove,
    this.onResize,
    this.onGrab,
    this.fallbackAspect = 1.6,
  });

  final String imageUrl;
  final List<FloorBoxData> boxes;
  final void Function(String id)? onTap;

  /// A drag of a box, as percent of the picture's width and height.
  final void Function(String id, double dxPercent, double dyPercent)? onMove;
  final void Function(String id, double dwPercent, double dhPercent)? onResize;

  /// A finger went down on a table that can be dragged (true), or came up / was cancelled (false). The screen stops its list scrolling meanwhile, so dragging a table never
  /// scrolls the page instead.
  final void Function(bool grabbed)? onGrab;

  /// Used until the picture says how wide and high it is (and when it cannot be loaded).
  final double fallbackAspect;

  @override
  State<FloorCanvas> createState() => _FloorCanvasState();
}

class _FloorCanvasState extends State<FloorCanvas> {
  double? _aspect;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (mounted && w > 0 && h > 0 && _aspect != w / h) setState(() => _aspect = w / h);
    },
    onError: (_, __) {},
  );

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(FloorCanvas old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) {
      _stream?.removeListener(_listener);
      _aspect = null;
      _resolve();
    }
  }

  void _resolve() {
    if (widget.imageUrl.isEmpty) return;
    _stream = NetworkImage(widget.imageUrl).resolve(const ImageConfiguration());
    _stream!.addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _aspect ?? widget.fallbackAspect,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              key: const Key('floor-canvas'),
              children: [
                Positioned.fill(
                  child: widget.imageUrl.isEmpty
                      ? const ColoredBox(color: Color(0xFF2A2A2A), child: Center(child: Icon(Icons.image_outlined)))
                      : Image.network(widget.imageUrl, fit: BoxFit.fill, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2A2A), child: Center(child: Icon(Icons.broken_image_outlined)))),
                ),
                for (final b in widget.boxes) _box(b, w, h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _box(FloorBoxData b, double w, double h) {
    final editable = widget.onMove != null && b.selected;
    final left = b.box.x / 100 * w;
    final top = b.box.y / 100 * h;
    final width = b.box.w / 100 * w;
    final height = b.box.h / 100 * h;
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: Key('box-${b.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap == null ? null : () => widget.onTap!(b.id),
              onPanDown: editable ? (_) => widget.onGrab?.call(true) : null,
              onPanUpdate: editable ? (d) => widget.onMove!(b.id, d.delta.dx / w * 100, d.delta.dy / h * 100) : null,
              onPanEnd: editable ? (_) => widget.onGrab?.call(false) : null,
              onPanCancel: editable ? () => widget.onGrab?.call(false) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: b.color.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: b.selected ? Colors.white : Colors.black54, width: b.selected ? 2.5 : 1),
                ),
                padding: const EdgeInsets.all(2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(b.label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center),
                      if (b.sublabel != null) Text(b.sublabel!, style: const TextStyle(color: Colors.black87, fontSize: 10), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (editable && widget.onResize != null)
            Positioned(
              right: -10,
              bottom: -10,
              child: GestureDetector(
                key: Key('resize-${b.id}'),
                behavior: HitTestBehavior.opaque,
                onPanDown: (_) => widget.onGrab?.call(true),
                onPanUpdate: (d) => widget.onResize!(b.id, d.delta.dx / w * 100, d.delta.dy / h * 100),
                onPanEnd: (_) => widget.onGrab?.call(false),
                onPanCancel: () => widget.onGrab?.call(false),
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  child: Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black87))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
