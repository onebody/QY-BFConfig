import "dart:typed_data";

import "msp_frame.dart";

final class MspCodec {
  Uint8List encode(MspFrame frame) {
    return switch (frame.version) {
      MspVersion.v1 => _encodeV1(frame),
      MspVersion.v2 => _encodeV2(frame),
    };
  }

  Uint8List _encodeV1(MspFrame frame) {
    final directionChar = switch (frame.direction) {
      MspDirection.toFlightController => "<",
      MspDirection.fromFlightController => ">",
    };

    final payloadSize = frame.payloadLength;
    if (payloadSize > 255) {
      throw ArgumentError.value(payloadSize, "payloadLength", "MSP v1 payload too large");
    }

    final out = BytesBuilder(copy: false);
    out.add([0x24, 0x4D, directionChar.codeUnitAt(0)]);
    out.add([payloadSize & 0xFF, frame.command & 0xFF]);
    out.add(frame.payload);

    var checksum = 0;
    checksum ^= payloadSize & 0xFF;
    checksum ^= frame.command & 0xFF;
    for (final b in frame.payload) {
      checksum ^= b;
    }
    out.add([checksum & 0xFF]);
    return out.toBytes();
  }

  Uint8List _encodeV2(MspFrame frame) {
    throw UnsupportedError("MSP v2 encode not implemented yet");
  }
}

