import "dart:async";
import "dart:typed_data";

enum LinkType {
  ble,
  wifi,
  usb,
}

enum LinkState {
  disconnected,
  connecting,
  connected,
}

abstract interface class Link {
  LinkType get type;
  Stream<LinkState> get states;
  Stream<Uint8List> get inbound;

  Future<void> connect();
  Future<void> disconnect();
  Future<void> send(Uint8List bytes);
}

final class LinkException implements Exception {
  LinkException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => "LinkException($message)";
}

