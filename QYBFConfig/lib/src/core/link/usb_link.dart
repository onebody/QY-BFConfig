import "dart:async";
import "dart:typed_data";

import "link.dart";

/// An opened USB serial port.
abstract interface class SerialPort {
  /// Opens the port and configures it for [baudRate] (8N1).
  Future<void> open(int baudRate);

  /// Bytes received from the flight controller.
  Stream<Uint8List> get inbound;

  /// Completes when the port is closed externally (device detached).
  Future<void> get closed;

  Future<void> write(Uint8List bytes);

  Future<void> close();
}

/// Opens a [SerialPort] by Android USB device id.
abstract interface class SerialTransport {
  Future<SerialPort> openPort(int deviceId);
}

final class UsbLink implements Link {
  UsbLink({
    required this.deviceId,
    required SerialTransport transport,
    this.baudRate = 115200,
  }) : _transport = transport;

  @override
  LinkType get type => LinkType.usb;

  final int deviceId;
  final int baudRate;
  final SerialTransport _transport;

  final _states = StreamController<LinkState>.broadcast();
  final _inbound = StreamController<Uint8List>.broadcast();

  LinkState _state = LinkState.disconnected;
  SerialPort? _port;
  StreamSubscription<Uint8List>? _inboundSub;
  Future<void> _writeTail = Future.value();

  @override
  Stream<LinkState> get states => _states.stream;

  @override
  Stream<Uint8List> get inbound => _inbound.stream;

  @override
  Future<void> connect() async {
    _setState(LinkState.connecting);
    try {
      final port = await _transport.openPort(deviceId);
      await port.open(baudRate);
      _port = port;
      _inboundSub = port.inbound.listen(_inbound.add);
      port.closed.then((_) => _handlePortClosed(port));
      _setState(LinkState.connected);
    } on Object catch (e) {
      _setState(LinkState.disconnected);
      throw LinkException("USB open of device $deviceId failed", cause: e);
    }
  }

  @override
  Future<void> disconnect() async {
    final port = _port;
    _port = null;
    await _inboundSub?.cancel();
    _inboundSub = null;
    await port?.close();
    _setState(LinkState.disconnected);
  }

  @override
  Future<void> send(Uint8List bytes) async {
    final port = _port;
    if (_state != LinkState.connected || port == null) {
      throw LinkException("send called while not connected");
    }
    final next = _writeTail.then((_) => port.write(bytes));
    _writeTail = next.catchError((_) {});
    return next;
  }

  void _handlePortClosed(SerialPort port) {
    if (!identical(port, _port)) {
      return;
    }
    disconnect();
  }

  void _setState(LinkState next) {
    _state = next;
    _states.add(next);
  }
}
