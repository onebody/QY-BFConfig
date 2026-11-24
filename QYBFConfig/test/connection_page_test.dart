import "dart:async";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "package:qybfconfig/src/core/link/ble_link.dart";
import "package:qybfconfig/src/core/link/ble_scan.dart";
import "package:qybfconfig/src/core/link/link.dart";
import "package:qybfconfig/src/core/link/usb_directory.dart";
import "package:qybfconfig/src/core/link/usb_link.dart";
import "package:qybfconfig/src/core/platform/permission_gate.dart";
import "package:qybfconfig/src/features/connection/connection_controller.dart";
import "package:qybfconfig/src/features/connection/connection_page.dart";

final class _Session implements BleSession {
  final _inbound = StreamController<Uint8List>.broadcast();
  final _closed = Completer<void>();

  @override
  Stream<Uint8List> get inbound => _inbound.stream;
  @override
  Future<void> get closed => _closed.future;
  @override
  Future<void> write(Uint8List bytes) async {}
  @override
  Future<void> dispose() async {}
}

final class _Transport implements BleTransport {
  bool allowConnect = true;

  @override
  Future<BleSession> connect(String remoteId) async {
    if (!allowConnect) throw LinkException("connect refused");
    return _Session();
  }
}

final class _UsbPort implements SerialPort {
  @override
  Future<void> open(int baudRate) async {}
  @override
  Stream<Uint8List> get inbound => const Stream.empty();
  @override
  Future<void> get closed => Completer<void>().future;
  @override
  Future<void> write(Uint8List bytes) async {}
  @override
  Future<void> close() async {}
}

final class _Scanner implements BleScanner {
  final _results = StreamController<List<BleScanEntry>>.broadcast();
  int startCount = 0;

  @override
  Stream<List<BleScanEntry>> get results => _results.stream;
  @override
  Future<void> start() async => startCount++;
  @override
  Future<void> stop() async {}
  void emit(List<BleScanEntry> entries) => _results.add(entries);
}

final class _Directory implements UsbDirectory {
  List<UsbDeviceEntry> devices = const [];
  @override
  Future<List<UsbDeviceEntry>> list() async => devices;
}

final class _Gate implements PermissionGate {
  bool granted = true;
  @override
  Future<bool> ensureBle() async => granted;
}

Widget _page({
  required _Scanner scanner,
  required _Directory directory,
  required _Gate gate,
  required _Transport transport,
}) {
  return ProviderScope(
    overrides: [
      bleScannerProvider.overrideWithValue(scanner),
      usbDirectoryProvider.overrideWithValue(directory),
      permissionGateProvider.overrideWithValue(gate),
      bleTransportProvider.overrideWithValue(transport),
      usbTransportProvider.overrideWithValue(_UsbTransport()),
    ],
    child: const MaterialApp(home: ConnectionPage()),
  );
}

final class _UsbTransport implements SerialTransport {
  @override
  Future<SerialPort> openPort(int deviceId) async => _UsbPort();
}

void main() {
  testWidgets("shows disconnected status with empty scan and usb sections", (
    tester,
  ) async {
    await tester.pumpWidget(_page(
      scanner: _Scanner(),
      directory: _Directory(),
      gate: _Gate(),
      transport: _Transport(),
    ));

    expect(find.text("未连接"), findsOneWidget);
    expect(find.text("蓝牙设备"), findsOneWidget);
    expect(find.text("USB 设备"), findsOneWidget);
  });

  testWidgets("scan reveals device and tap connects", (tester) async {
    final scanner = _Scanner();
    await tester.pumpWidget(_page(
      scanner: scanner,
      directory: _Directory(),
      gate: _Gate(),
      transport: _Transport(),
    ));

    await tester.tap(find.text("扫描"));
    await tester.pump();
    expect(scanner.startCount, 1);

    scanner.emit([
      const BleScanEntry(remoteId: "AA:BB", name: "SpeedyBee FC", rssi: -60),
    ]);
    await tester.pump();
    expect(find.text("SpeedyBee FC"), findsOneWidget);

    await tester.tap(find.text("SpeedyBee FC"));
    await tester.pumpAndSettle();
    expect(find.textContaining("已连接"), findsOneWidget);
    expect(find.textContaining("SpeedyBee FC"), findsWidgets);
  });

  testWidgets("permission denial shows error and stays disconnected", (
    tester,
  ) async {
    final scanner = _Scanner();
    final gate = _Gate()..granted = false;
    await tester.pumpWidget(_page(
      scanner: scanner,
      directory: _Directory(),
      gate: gate,
      transport: _Transport(),
    ));

    await tester.tap(find.text("扫描"));
    await tester.pump();
    scanner.emit([
      const BleScanEntry(remoteId: "AA:BB", name: "FC", rssi: -60),
    ]);
    await tester.pump();

    await tester.tap(find.text("FC"));
    await tester.pumpAndSettle();

    expect(find.textContaining("权限"), findsOneWidget);
    expect(find.text("未连接"), findsOneWidget);
  });

  testWidgets("connect failure surfaces error", (tester) async {
    final scanner = _Scanner();
    final transport = _Transport()..allowConnect = false;
    await tester.pumpWidget(_page(
      scanner: scanner,
      directory: _Directory(),
      gate: _Gate(),
      transport: transport,
    ));

    await tester.tap(find.text("扫描"));
    await tester.pump();
    scanner.emit([
      const BleScanEntry(remoteId: "AA:BB", name: "FC", rssi: -60),
    ]);
    await tester.pump();

    await tester.tap(find.text("FC"));
    for (var i = 0;
        i < 30 && find.textContaining("connect refused").evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.textContaining("connect refused"), findsOneWidget);
    expect(find.text("未连接"), findsOneWidget);
  });

  testWidgets("usb devices listed after refresh and connect", (tester) async {
    final directory = _Directory()
      ..devices = const [UsbDeviceEntry(deviceId: 7, label: "FTDI USB")];
    await tester.pumpWidget(_page(
      scanner: _Scanner(),
      directory: directory,
      gate: _Gate(),
      transport: _Transport(),
    ));

    await tester.tap(find.text("刷新"));
    await tester.pumpAndSettle();
    expect(find.text("FTDI USB"), findsOneWidget);

    await tester.tap(find.text("FTDI USB"));
    await tester.pumpAndSettle();
    expect(find.textContaining("已连接"), findsOneWidget);
  });
}
