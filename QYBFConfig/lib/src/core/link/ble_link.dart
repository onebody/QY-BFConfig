import "dart:async";
import "dart:typed_data";

import "link.dart";

/// An established BLE serial session (write characteristic + notify stream).
abstract interface class BleSession {
  /// Bytes received from the flight controller.
  Stream<Uint8List> get inbound;

  /// Completes when the underlying connection is lost.
  Future<void> get closed;

  Future<void> write(Uint8List bytes);

  Future<void> dispose();
}

/// Creates a [BleSession] for a remote device.
abstract interface class BleTransport {
  Future<BleSession> connect(String remoteId);
}

final class BleLink implements Link {
  BleLink({required this.remoteId, required BleTransport transport})
      : _transport = transport;

  @override
  LinkType get type => LinkType.ble;

  final String remoteId;
  final BleTransport _transport;

  final _states = StreamController<LinkState>.broadcast();
  final _inbound = StreamController<Uint8List>.broadcast();

  LinkState _state = LinkState.disconnected;
  BleSession? _session;
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
      final session = await _transport.connect(remoteId);
      _session = session;
      _inboundSub = session.inbound.listen(_inbound.add);
      session.closed.then((_) => _handleSessionClosed(session));
      _setState(LinkState.connected);
    } on Object catch (e) {
      _setState(LinkState.disconnected);
      throw LinkException("BLE connect to $remoteId failed", cause: e);
    }
  }

  @override
  Future<void> disconnect() async {
    final session = _session;
    _session = null;
    await _inboundSub?.cancel();
    _inboundSub = null;
    await session?.dispose();
    _setState(LinkState.disconnected);
  }

  @override
  Future<void> send(Uint8List bytes) async {
    final session = _session;
    if (_state != LinkState.connected || session == null) {
      throw LinkException("send called while not connected");
    }
    final next = _writeTail.then((_) => session.write(bytes));
    _writeTail = next.catchError((_) {});
    return next;
  }

  void _handleSessionClosed(BleSession session) {
    if (!identical(session, _session)) {
      return;
    }
    disconnect();
  }

  void _setState(LinkState next) {
    _state = next;
    _states.add(next);
  }
}
