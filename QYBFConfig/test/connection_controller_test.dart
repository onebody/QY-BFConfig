import "dart:async";
import "dart:typed_data";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "package:qybfconfig/src/core/link/ble_link.dart";
import "package:qybfconfig/src/core/link/ble_scan.dart";
import "package:qybfconfig/src/core/link/link.dart";
import "package:qybfconfig/src/core/link/usb_directory.dart";
import "package:qybfconfig/src/core/link/usb_link.dart";
import "package:qybfconfig/src/core/platform/permission_gate.dart";
import "package:qybfconfig/src/features/connection/connection_controller.dart";

final class _FakeBleSession implements BleSession {
  final _inbound = StreamController<Uint8List>.broadcast();
  final _closed = Completer<void>();

  @override
  Stream<Uint8List> get inbound => _inbound.stream;

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<void> write(Uint8List bytes) async {}

  @override
  Future<void> dispose() async {
    _inbound.close();
    if (!_closed.isCompleted) _closed.complete();
  }

  void drop() {
    if (!_closed.isCompleted) _closed.complete();
  }
}

final class _FakeBleTransport implements BleTransport {
  final List<String> connectedIds = [];
  Object? failWith;
  _FakeBleSession? lastSession;

  @override
  Future<BleSession> connect(String remoteId) async {
    if (failWith != null) throw failWith!;
    connectedIds.add(remoteId);
    final session = _FakeBleSession();
    lastSession = session;
    return session;
  }
}

final class _FakeSerialPort implements SerialPort {
  final _inbound = StreamController<Uint8List>.broadcast();
  final _closed = Completer<void>();

  @override
  Future<void> open(int baudRate) async {}

  @override
  Stream<Uint8List> get inbound => _inbound.stream;

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<void> write(Uint8List bytes) async {}

  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
  }
}

final class _FakeUsbTransport implements SerialTransport {
  final List<int> openedDeviceIds = [];
  Object? failWith;

  @override
  Future<SerialPort> openPort(int deviceId) async {
    if (failWith != null) throw failWith!;
    openedDeviceIds.add(deviceId);
    return _FakeSerialPort();
  }
}

final class _FakeScanner implements BleScanner {
  final _results = StreamController<List<BleScanEntry>>.broadcast();
  int startCount = 0;
  int stopCount = 0;
  Object? failOnStart;

  @override
  Stream<List<BleScanEntry>> get results => _results.stream;

  @override
  Future<void> start() async {
    if (failOnStart != null) throw failOnStart!;
    startCount++;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  void emit(List<BleScanEntry> entries) => _results.add(entries);
}

final class _FakeUsbDirectory implements UsbDirectory {
  List<UsbDeviceEntry> devices = const [];
  int refreshCount = 0;

  @override
  Future<List<UsbDeviceEntry>> list() async {
    refreshCount++;
    return devices;
  }
}

final class _FakeGate implements PermissionGate {
  bool? bleGranted;
  int callCount = 0;

  @override
  Future<bool> ensureBle() async {
    callCount++;
    return bleGranted ?? true;
  }
}

({
  ProviderContainer container,
  _FakeBleTransport bleTransport,
  _FakeUsbTransport usbTransport,
  _FakeScanner scanner,
  _FakeUsbDirectory directory,
  _FakeGate gate,
}) _createContainer() {
  final bleTransport = _FakeBleTransport();
  final usbTransport = _FakeUsbTransport();
  final scanner = _FakeScanner();
  final directory = _FakeUsbDirectory();
  final gate = _FakeGate();
  final container = ProviderContainer(overrides: [
    bleTransportProvider.overrideWithValue(bleTransport),
    usbTransportProvider.overrideWithValue(usbTransport),
    bleScannerProvider.overrideWithValue(scanner),
    usbDirectoryProvider.overrideWithValue(directory),
    permissionGateProvider.overrideWithValue(gate),
  ]);
  return (
    container: container,
    bleTransport: bleTransport,
    usbTransport: usbTransport,
    scanner: scanner,
    directory: directory,
    gate: gate,
  );
}

void main() {
  test("initial state is disconnected with empty lists", () {
    final t = _createContainer();
    addTearDown(t.container.dispose);

    final state = t.container.read(connectionControllerProvider);
    expect(state.linkState, LinkState.disconnected);
    expect(state.activeType, isNull);
    expect(state.bleResults, isEmpty);
    expect(state.usbDevices, isEmpty);
    expect(state.error, isNull);
  });

  test("startBleScan flips scanning and streams scan entries", () async {
    final t = _createContainer();
    addTearDown(t.container.dispose);
    final controller = t.container.read(connectionControllerProvider.notifier);

    await controller.startBleScan();
    expect(t.container.read(connectionControllerProvider).scanning, isTrue);

    t.scanner.emit([
      const BleScanEntry(remoteId: "AA:BB", name: "SpeedyBee FC", rssi: -55),
    ]);
    await Future<void>.delayed(Duration.zero);

    final state = t.container.read(connectionControllerProvider);
    expect(state.bleResults.single.remoteId, "AA:BB");
    expect(state.bleResults.single.name, "SpeedyBee FC");
  });

  test("stopBleScan resets scanning and stops the scanner", () async {
    final t = _createContainer();
    addTearDown(t.container.dispose);
    final controller = t.container.read(connectionControllerProvider.notifier);

    await controller.startBleScan();
    await controller.stopBleScan();

    final state = t.container.read(connectionControllerProvider);
    expect(state.scanning, isFalse);
    expect(t.scanner.stopCount, 1);
  });

  test("scan start failure surfaces error and stops scanning", () async {
    final t = _createContainer();
    addTearDown(t.container.dispose);
    t.scanner.failOnStart = LinkException("adapter off");
    final controller = t.container.read(connectionControllerProvider.notifier);

    await controller.startBleScan();

    final state = t.container.read(connectionControllerProvider);
    expect(state.scanning, isFalse);
    expect(state.error, contains("adapter off"));
  });

  test("connectBle without permission sets error and skips transport", () async {
    final t = _createContainer();
    addTearDown(t.container.dispose);
    t.gate.bleGranted = false;
    final controller = t.container.read(connectionControllerProvider.notifier);

    await controller.connectBle(
      const BleScanEntry(remoteId: "AA:BB", name: "FC", rssi: -60),
    );

    final state = t.container.read(connectionControllerProvider);
    expect(state.error, contains("权限"));
    expect(state.linkState, LinkState.disconnected);
    expect(t.bleTransport.connectedIds, isEmpty);
  });

  test("connectBle success tracks link state and active device", () async {
    final t = _createContainer();
    addTearDown(t.container.dispose);
    final controller = t.container.read(connectionControllerProvider.notifier);

    await controller.connectBle(
      const BleScanEntry(remoteId: "AA:BB", name: "FC", rssi: -60),
    );
    await Future<void>.delayed(Duration.zero);

    final state = t.container.read(connectionControllerProvider);
    expect(state.linkState, LinkState.connected);
    expect(state.activeType, LinkType.ble);
    expect(state.activeLabel, "FC");
    expect(t.container.read(connectionControllerProvider.notifier).currentLink?.type, LinkType.ble);
  });

  test("ble session drop updates ui state to disconnected", () async {
    final t = _createContainer();
    addTearDown(t.container.dispose);
    final controller = t.container.read(connectionControllerProvider.notifier);

    await controller.connectBle(
      const BleScanEntry(remoteId: "AA:BB", name: "FC", rssi: -60),
    );
    t.bleTransport.lastSession!.drop();
    await Future<void>.delayed(Duration.zero);

    expect(t.container.read(connectionControllerProvider).linkState, LinkState.disconnected);
  });

  test("connectBle transport failure surfaces error and stays disconnected", () async {
    final t = _createContainer();
    addTearDown(t.container.dispose);
    t.bleTransport.failWith = LinkException("device unreachable");
    final controller = t.container.read(connectionControllerProvider.notifier);

    await controller.connectBle(
      const BleScanEntry(remoteId: "AA:BB", name: "FC", rssi: -60),
    );

    final state = t.container.read(connectionControllerProvider);
    expect(state.linkState, LinkState.disconnected);
    expect(state.error, contains("device unreachable"));
  });

  test("connectBle while connected switches to the new device", () async {
    final t = _createContainer();
    addTearDown(t.container.dispose);
    final controller = t.container.read(connectionControllerProvider.notifier);

    await controller.connectBle(
      const BleScanEntry(remoteId: "AA:BB", name: "FC1", rssi: -60),
    );
    await controller.connectBle(
      const BleScanEntry(remoteId: "CC:DD", name: "FC2", rssi: -70),
    );
    await Future<void>.delayed(Duration.zero);

    final state = t.container.read(connectionControllerProvider);
    expect(state.activeLabel, "FC2");
    expect(t.bleTransport.connectedIds, ["AA:BB", "CC:DD"]);
  });

  test("refreshUsb loads device list", () async {
    final t = _createContainer();
    addTearDown(t.container.dispose);
    t.directory.devices = const [UsbDeviceEntry(deviceId: 7, label: "FTDI")];
    final controller = t.container.read(connectionControllerProvider.notifier);

    await controller.refreshUsb();

    final state = t.container.read(connectionControllerProvider);
    expect(state.usbDevices.single.label, "FTDI");
    expect(t.directory.refreshCount, 1);
  });

  test("connectUsb success sets active usb link", () async {
    final t = _createContainer();
    addTearDown(t.container.dispose);
    final controller = t.container.read(connectionControllerProvider.notifier);

    await controller.connectUsb(const UsbDeviceEntry(deviceId: 7, label: "FTDI"));
    await Future<void>.delayed(Duration.zero);

    final state = t.container.read(connectionControllerProvider);
    expect(state.linkState, LinkState.connected);
    expect(state.activeType, LinkType.usb);
    expect(t.usbTransport.openedDeviceIds, [7]);
  });

  test("connectUsb failure surfaces error", () async {
    final t = _createContainer();
    addTearDown(t.container.dispose);
    t.usbTransport.failWith = StateError("no permission");
    final controller = t.container.read(connectionControllerProvider.notifier);

    await controller.connectUsb(const UsbDeviceEntry(deviceId: 7, label: "FTDI"));

    final state = t.container.read(connectionControllerProvider);
    expect(state.linkState, LinkState.disconnected);
    expect(state.error, contains("no permission"));
  });

  test("disconnect closes link and clears active device", () async {
    final t = _createContainer();
    addTearDown(t.container.dispose);
    final controller = t.container.read(connectionControllerProvider.notifier);

    await controller.connectBle(
      const BleScanEntry(remoteId: "AA:BB", name: "FC", rssi: -60),
    );
    await controller.disconnect();
    await Future<void>.delayed(Duration.zero);

    final state = t.container.read(connectionControllerProvider);
    expect(state.linkState, LinkState.disconnected);
    expect(state.activeLabel, isNull);
    expect(controller.currentLink, isNull);
  });

  test("starting a new scan clears previous results first", () async {
    final t = _createContainer();
    addTearDown(t.container.dispose);
    final controller = t.container.read(connectionControllerProvider.notifier);

    await controller.startBleScan();
    t.scanner.emit([
      const BleScanEntry(remoteId: "OLD", name: "old", rssi: -80),
    ]);
    await Future<void>.delayed(Duration.zero);
    await controller.stopBleScan();

    await controller.startBleScan();
    expect(t.container.read(connectionControllerProvider).bleResults, isEmpty);
  });
}
