import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../logic/media_rules.dart';

/// A photo could not be uploaded; the message is a plain sentence for the person.
class MediaException implements Exception {
  const MediaException(this.message);

  final String message;

  @override
  String toString() => 'MediaException($message)';
}

/// Writes a file to storage and returns its public address. Replaced in tests; in the app it is the `business-media` bucket.
typedef MediaUploader = Future<String> Function(String path, Uint8List bytes, String contentType);

/// How a photo is written to storage: with its real type, cached for a year (a photo never changes: a replacement is a new file), and
/// never over an existing file, so a new upload can never overwrite someone else's photo.
FileOptions mediaFileOptions(String contentType) => FileOptions(contentType: contentType, cacheControl: '31536000', upsert: false);

/// Uploads a business's photos (venue cover, floor plans) into its own folder of the `business-media` bucket. The bucket itself
/// enforces who may write where (a person must belong to the business whose folder it is) and what it will take (JPEG, PNG, WebP,
/// 5 MB), so a page cannot grant itself anything; the checks here only give a clear sentence first.
class MediaService {
  MediaService({SupabaseClient? client, MediaUploader? uploader, String Function()? newId})
      : _client = client,
        _uploader = uploader,
        _newId = newId ?? (() => const Uuid().v4());

  final SupabaseClient? _client;
  final MediaUploader? _uploader;
  final String Function() _newId;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  static const String bucket = 'business-media';

  Future<String> _upload(String path, Uint8List bytes, String contentType) async {
    final custom = _uploader;
    if (custom != null) return custom(path, bytes, contentType);
    await _db.storage.from(bucket).uploadBinary(path, bytes, fileOptions: mediaFileOptions(contentType));
    return _db.storage.from(bucket).getPublicUrl(path);
  }

  /// Uploads [bytes] into the folder of [orgId] and returns the public address. Never a raw error: a file that is not allowed is a
  /// sentence, and so is a refusal from storage.
  Future<String> uploadBusinessImage(String orgId, Uint8List bytes) async {
    final problem = imageProblem(bytes);
    if (problem != null) throw MediaException(problem);
    final type = sniffImageType(bytes)!;
    try {
      return await _upload(mediaPath(orgId, type, _newId()), bytes, type.mime);
    } catch (_) {
      throw const MediaException(uploadFailedMessage);
    }
  }
}
