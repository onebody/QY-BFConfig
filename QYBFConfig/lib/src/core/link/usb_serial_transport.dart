import "dart:async";
import "dart:typed_data";

import "package:usb_serial/usb_serial.dart";

import "usb_link.dart";

/// Real [SerialTransport] on top of the usb_serial plugin.
///
/// Opening a port triggers the Android USB permission dialog when needed.
final class UsbSerialTransport implements SerialTransport {
  const UsbSerialTransport();

  @override
  Future<SerialPort> openPort(int deviceId) async {
    final port = await UsbSerial.createFromDeviceId(deviceId);
    if (port == null) {
      throw StateError("USB device $deviceId could not be opened");
    }
    return _UsbSerialPluginPort(port: port, deviceId: deviceId);
  }
}

final class _UsbSerialPluginPort implements SerialPort {
  _UsbSerialPluginPort({required this.port, required this.deviceId});

  final UsbPort port;
  final int deviceId;

  final _closed = Completer<void>();
  StreamSubscription<UsbEvent>? _detachSub;

  @override
  Future<void> open(int baudRate) async {
    if (!await port.open()) {
      throw StateError("USB port open failed for device $deviceId");
    }
    await port.setPortParameters(
      baudRate,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    _detachSub = UsbSerial.usbEventStream?.listen((event) {
      if (event.event == UsbEvent.ACTION_USB_DETACHED &&
          event.device?.deviceId == deviceId &&
          !_closed.isCompleted) {
        _closed.complete();
      }
    });
  }

  @override
  Stream<Uint8List> get inbound => port.inputStream!;

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<void> write(Uint8List bytes) => port.write(bytes);

  @override
  Future<void> close() async {
    await _detachSub?.cancel();
    _detachSub = null;
    await port.close();
    if (!_closed.isCompleted) {
      _closed.complete();
    }
  }
}
