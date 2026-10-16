import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Builds the camera view. [onCode] must be called with every code the camera reads. Replaced in tests, where there is no camera.
typedef QrCameraBuilder = Widget Function(BuildContext context, ValueChanged<String> onCode);

/// A QR camera with the two failures every scanner has said in words: access is off, or the camera could not start. The screen around it
/// always keeps a way to type the code, because a camera can be denied, dirty or missing.
class QrCameraView extends StatefulWidget {
  const QrCameraView({super.key, required this.onCode});

  final ValueChanged<String> onCode;

  @override
  State<QrCameraView> createState() => _QrCameraViewState();
}

class _QrCameraViewState extends State<QrCameraView> {
  late final MobileScannerController _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        for (final b in capture.barcodes) {
          final value = b.rawValue;
          if (value != null) {
            widget.onCode(value);
            break;
          }
        }
      },
      errorBuilder: (context, error) {
        final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
        return Container(
          key: const Key('camera-problem'),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            denied ? 'Camera access is off. Allow it in Settings, or type the code below.' : 'The camera could not start. Type the code below.',
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
