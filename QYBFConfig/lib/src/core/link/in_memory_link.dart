import "dart:async";
import "dart:typed_data";

import "link.dart";

final class InMemoryLink implements Link {
  InMemoryLink({required this.type});

  @override
  final LinkType type;

  final _states = StreamController<LinkState>.broadcast();
  final _inbound = StreamController<Uint8List>.broadcast();
  final _outbound = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get outbound => _outbound.stream;

  @override
  Stream<LinkState> get states => _states.stream;

  @override
  Stream<Uint8List> get inbound => _inbound.stream;

  LinkState _state = LinkState.disconnected;

  @override
  Future<void> connect() async {
    _setState(LinkState.connecting);
    _setState(LinkState.connected);
  }

  @override
  Future<void> disconnect() async {
    _setState(LinkState.disconnected);
  }

  @override
  Future<void> send(Uint8List bytes) async {
    if (_state != LinkState.connected) {
      throw LinkException("send called while not connected");
    }
    _outbound.add(Uint8List.fromList(bytes));
  }

  void pushInbound(Uint8List bytes) {
    _inbound.add(Uint8List.fromList(bytes));
  }

  void _setState(LinkState next) {
    _state = next;
    _states.add(next);
  }

  Future<void> dispose() async {
    await _states.close();
    await _inbound.close();
    await _outbound.close();
  }
}

