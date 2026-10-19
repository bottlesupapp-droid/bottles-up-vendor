import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/table_service_providers.dart';
import '../services/receipt_service.dart';

/// Opens a stored receipt photo in a dialog, through a short-lived address (the bucket is private: only the people at that club can
/// read it). A failure is said in a snackbar, never a stack trace. [url] is what a test passes to skip the lookup.
Future<void> showReceipt(
  BuildContext context,
  WidgetRef ref,
  String path,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final String url;
  try {
    url = await ref.read(receiptServiceProvider).signedUrl(path);
  } on ReceiptException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder:
        (_) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    key: const Key('receipt-image'),
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'The photo could not be loaded.',
                            key: Key('receipt-image-error'),
                          ),
                        ),
                  ),
                ),
              ),
              TextButton(
                key: const Key('receipt-close'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
  );
}
