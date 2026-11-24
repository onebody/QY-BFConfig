import "dart:typed_data";

enum MspVersion {
  v1,
  v2,
}

enum MspDirection {
  toFlightController,
  fromFlightController,
}

enum MspV1Status {
  ok,
  error,
}

/// A decoded MSP message.
///
/// For MSP v1, [status] maps to '$M>' (ok) and '$M!' (error).
/// For MSP v2, [status] is currently always [MspV1Status.ok] and may be expanded.
final class MspFrame {
  MspFrame({
    required this.version,
    required this.direction,
    required this.command,
    required Uint8List payload,
    this.status = MspV1Status.ok,
  }) : payload = Uint8List.fromList(payload);

  final MspVersion version;
  final MspDirection direction;
  final int command;
  final Uint8List payload;
  final MspV1Status status;

  int get payloadLength => payload.length;
}

