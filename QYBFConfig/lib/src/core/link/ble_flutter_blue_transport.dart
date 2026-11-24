import "dart:async";
import "dart:typed_data";

import "package:flutter_blue_plus/flutter_blue_plus.dart";

import "ble_link.dart";
import "link.dart";

/// Real [BleTransport] on top of flutter_blue_plus.
final class FlutterBluePlusBleTransport implements BleTransport {
  FlutterBluePlusBleTransport({
    List<Guid>? mspServices,
    Duration connectTimeout = const Duration(seconds: 10),
    int? mtu = 247,
  })  : _mspServices = mspServices ?? defaultMspServiceUuids,
        _connectTimeout = connectTimeout,
        _mtu = mtu;

  /// Nordic UART Service (common Betaflight onboard BLE) and SpeedyBee's
  /// AE30 service, in probe order.
  static final defaultMspServiceUuids = <Guid>[
    Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e"),
    Guid("0000ae30-0000-1000-8000-00805f9b34fb"),
  ];

  static final _nusWriteUuid = Guid("6e400002-b5a3-f393-e0a9-e50e24dcca9e");
  static final _nusNotifyUuid = Guid("6e400003-b5a3-f393-e0a9-e50e24dcca9e");

  final List<Guid> _mspServices;
  final Duration _connectTimeout;
  final int? _mtu;

  @override
  Future<BleSession> connect(String remoteId) async {
    final device = BluetoothDevice.fromId(remoteId);
    await device.connect(timeout: _connectTimeout, mtu: _mtu);

    try {
      final services = await device.discoverServices();
      final selected = _pickWriteAndNotify(services, mspServices: _mspServices);
      if (selected == null) {
        throw LinkException(
          "no MSP serial service found on $remoteId "
          "(tried: ${_mspServices.map((e) => e.str).join(", ")})",
        );
      }
      final (writeChar, notifyChar) = selected;

      final closed = Completer<void>();
      final connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            !closed.isCompleted) {
          closed.complete();
        }
      });

      final session = _FlutterBlueBleSession(
        device: device,
        writeChar: writeChar,
        notifyChar: notifyChar,
        closed: closed,
        connectionSub: connectionSub,
      );
      await notifyChar.setNotifyValue(true);
      return session;
    } on Object catch (_) {
      await _safeDisconnect(device);
      rethrow;
    }
  }

  /// Finds write/notify characteristics inside the first matching candidate
  /// service. Nordic UART gets an exact UUID match; other services fall back
  /// to property-based selection (SpeedyBee uses one char for both).
  static (BluetoothCharacteristic, BluetoothCharacteristic)?
      _pickWriteAndNotify(
    List<BluetoothService> services, {
    required List<Guid> mspServices,
  }) {
    for (final candidate in mspServices) {
      BluetoothService? service;
      for (final s in services) {
        if (s.uuid == candidate) {
          service = s;
          break;
        }
      }
      if (service == null) {
        continue;
      }

      BluetoothCharacteristic? write;
      BluetoothCharacteristic? notify;
      for (final char in service.characteristics) {
        write ??= (char.uuid == _nusWriteUuid ||
                char.properties.write ||
                char.properties.writeWithoutResponse)
            ? char
            : null;
        notify ??= (char.uuid == _nusNotifyUuid ||
                char.properties.notify ||
                char.properties.indicate)
            ? char
            : null;
      }
      if (write != null && notify != null) {
        return (write, notify);
      }
    }
    return null;
  }

  static Future<void> _safeDisconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } on Object {
      // best effort
    }
  }
}

final class _FlutterBlueBleSession implements BleSession {
  _FlutterBlueBleSession({
    required BluetoothDevice device,
    required BluetoothCharacteristic writeChar,
    required BluetoothCharacteristic notifyChar,
    required Completer<void> closed,
    required StreamSubscription<BluetoothConnectionState> connectionSub,
  })  : _device = device,
        _writeChar = writeChar,
        _notifyChar = notifyChar,
        _closed = closed,
        _connectionSub = connectionSub;

  final BluetoothDevice _device;
  final BluetoothCharacteristic _writeChar;
  final BluetoothCharacteristic _notifyChar;
  final Completer<void> _closed;
  final StreamSubscription<BluetoothConnectionState> _connectionSub;

  @override
  late final Stream<Uint8List> inbound =
      _notifyChar.onValueReceived.map(Uint8List.fromList);

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<void> write(Uint8List bytes) async {
    await _writeChar.write(
      bytes,
      withoutResponse: _writeChar.properties.writeWithoutResponse,
    );
  }

  @override
  Future<void> dispose() async {
    await _connectionSub.cancel();
    try {
      await _notifyChar.setNotifyValue(false);
    } on Object {
      // device may already be gone
    }
    if (!_closed.isCompleted) {
      _closed.complete();
    }
    await FlutterBluePlusBleTransport._safeDisconnect(_device);
  }
}
