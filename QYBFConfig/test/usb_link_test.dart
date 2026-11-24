import "dart:async";
import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";

import "package:qybfconfig/src/core/link/link.dart";
import "package:qybfconfig/src/core/link/usb_link.dart";

final class _FakePort implements SerialPort {
  final _inbound = StreamController<Uint8List>.broadcast();
  final _closed = Completer<void>();
  final opens = <String>[];
  final writes = <Uint8List>[];

  int? baudApplied;
  Completer<void>? writeBlocker;

  @override
  Future<void> open(int baudRate) async {
    opens.add("open@$baudRate");
    baudApplied = baudRate;
  }

  @override
  Stream<Uint8List> get inbound => _inbound.stream;

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<void> write(Uint8List bytes) async {
    writes.add(bytes);
    await writeBlocker?.future;
  }

  @override
  Future<void> close() async {
    opens.add("close");
    if (!_closed.isCompleted) _closed.complete();
    await _inbound.close();
  }

  void emitInbound(Uint8List bytes) => _inbound.add(bytes);

  void emitClosed() {
    if (!_closed.isCompleted) _closed.complete();
  }
}

final class _FakeTransport implements SerialTransport {
  final Future<SerialPort> Function(int deviceId) opener;

  _FakeTransport(this.opener);

  @override
  Future<SerialPort> openPort(int deviceId) => opener(deviceId);
}

void main() {
  test("connect opens port at 115200 and emits connecting then connected", () async {
    final port = _FakePort();
    final link = UsbLink(
      deviceId: 7,
      transport: _FakeTransport((_) async => port),
    );

    final states = <LinkState>[];
    link.states.listen(states.add);
    await link.connect();
    await Future<void>.delayed(Duration.zero);

    expect(port.opens, ["open@115200"]);
    expect(states, [LinkState.connecting, LinkState.connected]);
  });

  test("custom baudRate is applied on connect", () async {
    final port = _FakePort();
    final link = UsbLink(
      deviceId: 7,
      transport: _FakeTransport((_) async => port),
      baudRate: 921600,
    );

    await link.connect();

    expect(port.opens, ["open@921600"]);
  });

  test("send before connect throws LinkException", () async {
    final link = UsbLink(
      deviceId: 7,
      transport: _FakeTransport((_) async => _FakePort()),
    );

    await expectLater(link.send(Uint8List.fromList([1])), throwsA(isA<LinkException>()));
  });

  test("port inbound is exposed on link inbound", () async {
    final port = _FakePort();
    final link = UsbLink(
      deviceId: 7,
      transport: _FakeTransport((_) async => port),
    );
    await link.connect();

    final received = <Uint8List>[];
    link.inbound.listen(received.add);
    await Future<void>.delayed(Duration.zero);

    port.emitInbound(Uint8List.fromList([0x24, 0x4d]));
    await Future<void>.delayed(Duration.zero);

    expect(received.single, [0x24, 0x4d]);
  });

  test("writes are serialized: next send waits for previous write", () async {
    final port = _FakePort()..writeBlocker = Completer<void>();
    final link = UsbLink(
      deviceId: 7,
      transport: _FakeTransport((_) async => port),
    );
    await link.connect();

    final first = link.send(Uint8List.fromList([1]));
    final second = link.send(Uint8List.fromList([2]));

    await Future<void>.delayed(Duration.zero);
    expect(port.writes, hasLength(1));

    port.writeBlocker!.complete();
    await Future.wait([first, second]);
    expect(port.writes, [
      Uint8List.fromList([1]),
      Uint8List.fromList([2]),
    ]);
  });

  test("port closure moves link to disconnected and blocks send", () async {
    final port = _FakePort();
    final link = UsbLink(
      deviceId: 7,
      transport: _FakeTransport((_) async => port),
    );

    final states = <LinkState>[];
    link.states.listen(states.add);
    await link.connect();

    port.emitClosed();
    await Future<void>.delayed(Duration.zero);

    expect(states, [LinkState.connecting, LinkState.connected, LinkState.disconnected]);
    await expectLater(link.send(Uint8List.fromList([1])), throwsA(isA<LinkException>()));
  });

  test("failed connect rolls back to disconnected and throws LinkException", () async {
    final link = UsbLink(
      deviceId: 7,
      transport: _FakeTransport((_) async => throw StateError("no device")),
    );

    final states = <LinkState>[];
    link.states.listen(states.add);

    await expectLater(link.connect(), throwsA(isA<LinkException>()));
    await Future<void>.delayed(Duration.zero);

    expect(states, [LinkState.connecting, LinkState.disconnected]);
  });

  test("disconnect closes port and emits disconnected", () async {
    final port = _FakePort();
    final link = UsbLink(
      deviceId: 7,
      transport: _FakeTransport((_) async => port),
    );

    final states = <LinkState>[];
    link.states.listen(states.add);
    await link.connect();

    await link.disconnect();
    await Future<void>.delayed(Duration.zero);

    expect(port.opens, ["open@115200", "close"]);
    expect(states.last, LinkState.disconnected);
  });
}
