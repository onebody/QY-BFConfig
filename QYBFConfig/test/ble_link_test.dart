import "dart:async";
import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";

import "package:qybfconfig/src/core/link/ble_link.dart";
import "package:qybfconfig/src/core/link/link.dart";

final class _FakeSession implements BleSession {
  final _inbound = StreamController<Uint8List>.broadcast();
  final _closed = Completer<void>();
  final writes = <Uint8List>[];
  final _writeGate = StreamController<void>.broadcast();

  /// When set, write() does not complete until the gate is unblocked.
  Completer<void>? writeBlocker;

  @override
  Stream<Uint8List> get inbound => _inbound.stream;

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<void> write(Uint8List bytes) async {
    writes.add(bytes);
    _writeGate.add(null);
    await writeBlocker?.future;
  }

  @override
  Future<void> dispose() async {
    await _inbound.close();
  }

  void emitInbound(Uint8List bytes) => _inbound.add(bytes);

  void emitClosed() {
    if (!_closed.isCompleted) _closed.complete();
  }
}

final class _FakeTransport implements BleTransport {
  final Future<BleSession> Function(String remoteId) connector;

  _FakeTransport(this.connector);

  @override
  Future<BleSession> connect(String remoteId) => connector(remoteId);
}

void main() {
  test("connect emits connecting then connected", () async {
    final session = _FakeSession();
    final link = BleLink(
      remoteId: "AA:BB:CC:DD:EE:FF",
      transport: _FakeTransport((_) async => session),
    );

    final states = <LinkState>[];
    link.states.listen(states.add);

    await link.connect();
    await Future<void>.delayed(Duration.zero);

    expect(states, [LinkState.connecting, LinkState.connected]);
  });

  test("send before connect throws LinkException", () async {
    final link = BleLink(
      remoteId: "AA:BB:CC:DD:EE:FF",
      transport: _FakeTransport((_) async => _FakeSession()),
    );

    await expectLater(link.send(Uint8List.fromList([1, 2, 3])), throwsA(isA<LinkException>()));
  });

  test("session inbound is exposed on link inbound", () async {
    final session = _FakeSession();
    final link = BleLink(
      remoteId: "AA:BB:CC:DD:EE:FF",
      transport: _FakeTransport((_) async => session),
    );
    await link.connect();

    final received = <Uint8List>[];
    link.inbound.listen(received.add);
    await Future<void>.delayed(Duration.zero);

    session.emitInbound(Uint8List.fromList([0x24, 0x4d]));
    await Future<void>.delayed(Duration.zero);

    expect(received.single, [0x24, 0x4d]);
  });

  test("writes are serialized: next send waits for previous write", () async {
    final session = _FakeSession()..writeBlocker = Completer<void>();
    final link = BleLink(
      remoteId: "AA:BB:CC:DD:EE:FF",
      transport: _FakeTransport((_) async => session),
    );
    await link.connect();

    final first = link.send(Uint8List.fromList([1]));
    final second = link.send(Uint8List.fromList([2]));

    await Future<void>.delayed(Duration.zero);
    expect(session.writes, hasLength(1));

    session.writeBlocker!.complete();
    await Future.wait([first, second]);
    expect(session.writes, [
      Uint8List.fromList([1]),
      Uint8List.fromList([2]),
    ]);
  });

  test("session closure moves link to disconnected and blocks send", () async {
    final session = _FakeSession();
    final link = BleLink(
      remoteId: "AA:BB:CC:DD:EE:FF",
      transport: _FakeTransport((_) async => session),
    );

    final states = <LinkState>[];
    link.states.listen(states.add);
    await link.connect();

    session.emitClosed();
    await Future<void>.delayed(Duration.zero);

    expect(states, [LinkState.connecting, LinkState.connected, LinkState.disconnected]);
    await expectLater(link.send(Uint8List.fromList([1])), throwsA(isA<LinkException>()));
  });

  test("failed connect rolls back to disconnected and throws LinkException", () async {
    final link = BleLink(
      remoteId: "AA:BB:CC:DD:EE:FF",
      transport: _FakeTransport((_) async => throw StateError("boom")),
    );

    final states = <LinkState>[];
    link.states.listen(states.add);

    await expectLater(link.connect(), throwsA(isA<LinkException>()));
    await Future<void>.delayed(Duration.zero);

    expect(states, [LinkState.connecting, LinkState.disconnected]);
  });

  test("disconnect disposes session and emits disconnected", () async {
    final session = _FakeSession();
    var disposed = false;
    final transport = _FakeTransport((_) async {
      return _ProxySession(session, onDispose: () => disposed = true);
    });
    final link = BleLink(remoteId: "AA:BB:CC:DD:EE:FF", transport: transport);

    final states = <LinkState>[];
    link.states.listen(states.add);
    await link.connect();

    await link.disconnect();
    await Future<void>.delayed(Duration.zero);

    expect(disposed, isTrue);
    expect(states.last, LinkState.disconnected);
  });
}

final class _ProxySession implements BleSession {
  _ProxySession(this._inner, {required this.onDispose});

  final BleSession _inner;
  final void Function() onDispose;

  @override
  Stream<Uint8List> get inbound => _inner.inbound;

  @override
  Future<void> get closed => _inner.closed;

  @override
  Future<void> write(Uint8List bytes) => _inner.write(bytes);

  @override
  Future<void> dispose() async {
    onDispose();
    await _inner.dispose();
  }
}
