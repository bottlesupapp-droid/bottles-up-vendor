// Photos for a business (venue cover, floor plans). Pure Dart, tested without a screen. The same rules as the website's
// src/lib/uploadBusinessMedia.ts and the storage bucket's own limits (website repo, 20261007100000_accounts_onboarding.sql): the bucket
// `business-media` takes JPEG, PNG and WebP up to 5 MB, and a file may only be written inside the folder of a business the person
// belongs to: `<organization id>/<file>`. Checking first just gives the person a clear sentence instead of a storage error.

import 'dart:typed_data';

const int maxImageBytes = 5 * 1024 * 1024;

enum ImageType {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp');

  const ImageType(this.mime, this.extension);

  final String mime;
  final String extension;
}

bool _startsWith(Uint8List b, List<int> prefix, [int offset = 0]) {
  if (b.length < offset + prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (b[offset + i] != prefix[i]) return false;
  }
  return true;
}

/// What the file really is, from its first bytes (not from its name, which a person or a picker may get wrong). Null for anything that
/// is not a JPEG, PNG or WebP, including an iPhone HEIC photo.
ImageType? sniffImageType(Uint8List bytes) {
  if (_startsWith(bytes, [0xFF, 0xD8, 0xFF])) return ImageType.jpeg;
  if (_startsWith(bytes, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return ImageType.png;
  if (_startsWith(bytes, [0x52, 0x49, 0x46, 0x46]) && _startsWith(bytes, [0x57, 0x45, 0x42, 0x50], 8)) return ImageType.webp;
  return null;
}

/// A sentence describing what is wrong with the image, or null if it can be uploaded.
String? imageProblem(Uint8List bytes) {
  if (bytes.isEmpty) return 'That file is empty.';
  if (sniffImageType(bytes) == null) return 'Use a JPEG, PNG or WebP image.';
  if (bytes.length > maxImageBytes) return 'The image is larger than 5 MB. Choose a smaller one.';
  return null;
}

/// The storage path: always inside the business's own folder, which is what the database policy checks.
String mediaPath(String orgId, ImageType type, String id) => '$orgId/$id.${type.extension}';

/// What is said when the storage refuses an upload that passed the checks above (no access, or a file the bucket does not allow).
const String uploadFailedMessage = 'The image could not be uploaded. You may not have access, or the file is not allowed.';
