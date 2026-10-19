import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../owner/logic/media_rules.dart';
import '../logic/table_service_rules.dart';

/// A receipt photo could not be uploaded or opened; the message is a plain sentence for the person.
class ReceiptException implements Exception {
  const ReceiptException(this.message);

  final String message;

  @override
  String toString() => 'ReceiptException($message)';
}

/// A receipt that is in storage: where it is filed and its SHA-256, which the database uses to refuse a photo already used for
/// another payment at the club.
class ReceiptUpload {
  const ReceiptUpload({required this.path, required this.hash});

  final String path;
  final String hash;
}

/// Writes a receipt photo to storage. Replaced in tests; in the app it is the private `club-payment-receipts` bucket.
typedef ReceiptUploader =
    Future<void> Function(String path, Uint8List bytes, String contentType);

/// Makes a short-lived address to look at a receipt. Replaced in tests.
typedef ReceiptSigner = Future<String> Function(String path);

/// How a receipt photo is written: with its real type, cached for an hour, and never over an existing file, so a new upload can never
/// replace someone else's evidence.
FileOptions receiptFileOptions(String contentType) =>
    FileOptions(contentType: contentType, cacheControl: '3600', upsert: false);

const String receiptUploadFailed =
    'The receipt photo could not be uploaded. You may not have access to this table, or the connection dropped.';
const String receiptOpenFailed = 'The receipt photo could not be opened.';

/// Uploads receipt photos into the private `club-payment-receipts` bucket, filed under the booking's own id
/// (`<booking id>/<file>`). The bucket's policy lets only a manager or the table's server add a photo there and only the people at
/// that club read it (website repo, 20261014130000_desk_payments.sql); a page cannot grant itself anything. A photo is never
/// overwritten: every upload is a new file.
class ReceiptService {
  ReceiptService({
    SupabaseClient? client,
    ReceiptUploader? uploader,
    ReceiptSigner? signer,
    String Function()? newId,
  }) : _client = client,
       _uploader = uploader,
       _signer = signer,
       _newId = newId ?? (() => const Uuid().v4());

  final SupabaseClient? _client;
  final ReceiptUploader? _uploader;
  final ReceiptSigner? _signer;
  final String Function() _newId;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  static const String bucket = 'club-payment-receipts';

  /// Uploads [bytes] for [bookingId] and returns where it is filed and its hash. A file that is not a JPEG, PNG or WebP of at most 5 MB
  /// is refused with a sentence before anything is sent.
  Future<ReceiptUpload> upload(String bookingId, Uint8List bytes) async {
    final problem = imageProblem(bytes);
    if (problem != null) throw ReceiptException(problem);
    final type = sniffImageType(bytes)!;
    final path = receiptStoragePath(bookingId, type.extension, _newId());
    try {
      final custom = _uploader;
      if (custom != null) {
        await custom(path, bytes, type.mime);
      } else {
        await _db.storage
            .from(bucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: receiptFileOptions(type.mime),
            );
      }
    } catch (_) {
      throw const ReceiptException(receiptUploadFailed);
    }
    return ReceiptUpload(path: path, hash: sha256.convert(bytes).toString());
  }

  /// A short-lived address to look at a stored receipt (valid for five minutes).
  Future<String> signedUrl(String path) async {
    try {
      final custom = _signer;
      if (custom != null) return await custom(path);
      return await _db.storage.from(bucket).createSignedUrl(path, 300);
    } catch (_) {
      throw const ReceiptException(receiptOpenFailed);
    }
  }
}
