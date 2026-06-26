import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'dart:io';

import '../../../shared/services/check_in_service.dart';
import '../providers/scanner_provider.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  /// When provided, scanner is scoped to this event's tickets only.
  /// When null, scanner accepts any ticket belonging to the current vendor.
  final String? eventId;

  const QRScannerScreen({super.key, this.eventId});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isProcessing = false;
  bool flashOn = false;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) controller?.pauseCamera();
    controller?.resumeCamera();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController ctrl) {
    controller = ctrl;
    ctrl.scannedDataStream.listen((scan) {
      if (!isProcessing && scan.code != null) {
        _processTicket(scan.code!);
      }
    });
  }

  Future<void> _processTicket(String ticketCode) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);

    try {
      controller?.pauseCamera();
      final ticket = await ref.read(scannerProvider.notifier).checkInTicket(
            ticketCode,
            eventId: widget.eventId,
          );
      if (mounted) _showSuccessDialog(ticket);
    } catch (e) {
      if (mounted) _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => isProcessing = false);
      controller?.resumeCamera();
    }
  }

  void _showSuccessDialog(UnifiedTicket ticket) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Ionicons.checkmark_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ticket.source == TicketSource.event
                    ? 'Event Ticket — Check In'
                    : 'Table Reservation — Check In',
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Type', ticket.sourceLabel),
            _row('Booking', ticket.title),
            _row('Venue', ticket.venueName),
            if (ticket.guestEmail.isNotEmpty) _row('Email', ticket.guestEmail),
            if (ticket.guestPhone != null) _row('Phone', ticket.guestPhone!),
            _row('Guests / Qty', ticket.quantity.toString()),
            _row('Code', ticket.ticketCode),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAlreadyCheckedIn(UnifiedTicket ticket) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Ionicons.warning, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Text('Already Checked In', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Booking', ticket.title),
            if (ticket.checkedInAt != null)
              _row('Time', _fmt(ticket.checkedInAt!)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    // Distinguish "already checked in" from other errors
    if (message.startsWith('Already checked in')) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Ionicons.warning, color: Colors.orange, size: 32),
              SizedBox(width: 12),
              Text('Already Checked In'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Ionicons.close_circle, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Check-In Failed'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
            ),
          ],
        ),
      );

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} '
      '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  void _toggleFlash() async {
    await controller?.toggleFlash();
    setState(() => flashOn = !flashOn);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEventScoped = widget.eventId != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(isEventScoped ? 'Scan Event Tickets' : 'Scan Tickets'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(flashOn ? Ionicons.flash : Ionicons.flash_outline),
            onPressed: _toggleFlash,
            tooltip: 'Toggle Flash',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.scaffoldBackgroundColor,
            child: isEventScoped
                ? ref.watch(scanStatsProvider(widget.eventId!)).when(
                      data: (s) => _statsRow(s),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox.shrink(),
                    )
                : ref.watch(vendorScanStatsProvider).when(
                      data: (s) => _statsRow(s),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
          ),

          // QR view
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: const Color(0xFFFF6B35),
                    borderRadius: 12,
                    borderLength: 40,
                    borderWidth: 8,
                    cutOutSize: MediaQuery.of(context).size.width * 0.7,
                  ),
                ),
                if (isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFF6B35)),
                    ),
                  ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(24),
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                const Icon(Ionicons.qr_code_outline,
                    size: 40, color: Color(0xFFFF6B35)),
                const SizedBox(height: 12),
                const Text(
                  'Position the QR code within the frame',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  isEventScoped
                      ? 'Scanning event tickets only'
                      : 'Scanning event tickets and table reservations',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(ScanStats s) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Total', s.total.toString(), Colors.blue),
          _statItem('Checked In', s.checkedIn.toString(), Colors.green),
          _statItem('Pending', s.pending.toString(), Colors.orange),
        ],
      );

  Widget _statItem(String label, String value, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}
