import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/owner_providers.dart';
import '../services/media_service.dart';

/// Lets the person choose a photo. Replaced in tests; in the app it is the phone's own gallery picker. The picker shrinks a large
/// photo to at most 2400 pixels wide and re-encodes it, which also turns an iPhone HEIC photo into a JPEG the bucket accepts.
typedef PhotoPicker = Future<Uint8List?> Function(BuildContext context);

Future<Uint8List?> pickPhotoFromGallery(BuildContext context) async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400, imageQuality: 88);
  return file?.readAsBytes();
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => pickPhotoFromGallery);

/// A photo to choose, with its preview. Uploads into the business's own folder as soon as it is chosen and hands back the public
/// address; nothing is saved to the venue until the form around it is saved. A required photo (a floor plan) cannot be removed, only
/// replaced, because there is nothing to remove it to.
class PhotoField extends ConsumerStatefulWidget {
  const PhotoField({
    super.key,
    required this.orgId,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onBusyChanged,
    this.wide = false,
    this.required = false,
    this.hint,
  });

  final String orgId;
  final String label;

  /// The public address of the current photo, or empty.
  final String value;
  final ValueChanged<String> onChanged;

  /// Told when an upload starts and ends, so the form can hold its Save button until the photo is there.
  final ValueChanged<bool>? onBusyChanged;
  final bool wide;
  final bool required;
  final String? hint;

  @override
  ConsumerState<PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends ConsumerState<PhotoField> {
  bool _busy = false;
  String? _error;

  void _setBusy(bool v) {
    if (mounted) setState(() => _busy = v);
    widget.onBusyChanged?.call(v);
  }

  Future<void> _choose() async {
    if (_busy) return;
    final bytes = await ref.read(photoPickerProvider)(context);
    if (bytes == null || !mounted) return;
    setState(() => _error = null);
    _setBusy(true);
    try {
      final url = await ref.read(mediaServiceProvider).uploadBusinessImage(widget.orgId, bytes);
      if (!mounted) return;
      widget.onChanged(url);
    } on MediaException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = widget.wide ? const Size(120, 72) : const Size(72, 72);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              key: const Key('photo-preview'),
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(8)),
              clipBehavior: Clip.antiAlias,
              child: widget.value.isEmpty
                  ? const Icon(Icons.image_outlined)
                  : Image.network(widget.value, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(key: const Key('photo-choose'), onPressed: _busy ? null : _choose, child: Text(widget.value.isEmpty ? 'Choose photo' : 'Replace photo')),
                  if (_busy) const SizedBox(key: Key('photo-busy'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  if (widget.value.isNotEmpty && !widget.required && !_busy)
                    TextButton(key: const Key('photo-remove'), onPressed: () => widget.onChanged(''), child: const Text('Remove photo')),
                ],
              ),
            ),
          ],
        ),
        if (widget.hint != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(widget.hint!, style: theme.textTheme.bodySmall)),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, key: const Key('photo-error'), style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFEF5350)))),
      ],
    );
  }
}

/// A photo shown small, on a list card. A photo that cannot be loaded (offline, removed) shows a placeholder instead of an error.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({super.key, required this.url, this.height = 120});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined))),
        ),
      );
}
