import "dart:typed_data";

import "msp_frame.dart";

final class MspParser {
  final _buffer = BytesBuilder(copy: false);

  /// Push a new chunk of bytes and return all fully decoded frames.
  List<MspFrame> push(Uint8List chunk) {
    if (chunk.isNotEmpty) {
      _buffer.add(chunk);
    }

    final frames = <MspFrame>[];
    var data = _buffer.toBytes();
    var offset = 0;

    while (true) {
      final start = _findSync(data, offset);
      if (start == null) {
        _resetWithRemainder(Uint8List(0));
        return frames;
      }

      if (data.length - start < 6) {
        _resetWithRemainder(Uint8List.sublistView(data, start));
        return frames;
      }

      final header1 = data[start];
      final header2 = data[start + 1];
      final direction = data[start + 2];

      if (header1 != 0x24 || header2 != 0x4D) {
        offset = start + 1;
        continue;
      }

      final directionChar = String.fromCharCode(direction);
      final status = switch (directionChar) {
        ">" => MspV1Status.ok,
        "!" => MspV1Status.error,
        _ => MspV1Status.ok,
      };

      final mspDirection = switch (directionChar) {
        "<" => MspDirection.toFlightController,
        _ => MspDirection.fromFlightController,
      };

      final payloadSize = data[start + 3];
      final command = data[start + 4];
      final frameLen = 3 + 2 + payloadSize + 1;

      if (data.length - start < frameLen) {
        _resetWithRemainder(Uint8List.sublistView(data, start));
        return frames;
      }

      final payloadStart = start + 5;
      final payloadEnd = payloadStart + payloadSize;
      final payload = Uint8List.sublistView(data, payloadStart, payloadEnd);
      final checksum = data[payloadEnd];

      var calc = 0;
      calc ^= payloadSize;
      calc ^= command;
      for (final b in payload) {
        calc ^= b;
      }

      if ((calc & 0xFF) != checksum) {
        offset = start + 1;
        continue;
      }

      frames.add(
        MspFrame(
          version: MspVersion.v1,
          direction: mspDirection,
          command: command,
          payload: payload,
          status: status,
        ),
      );

      offset = start + frameLen;
      if (offset >= data.length) {
        _resetWithRemainder(Uint8List(0));
        return frames;
      }
    }
  }

  int? _findSync(Uint8List data, int from) {
    for (var i = from; i + 2 < data.length; i++) {
      if (data[i] == 0x24 && data[i + 1] == 0x4D) {
        return i;
      }
    }
    return null;
  }

  void _resetWithRemainder(Uint8List remainder) {
    _buffer.clear();
    if (remainder.isNotEmpty) {
      _buffer.add(remainder);
    }
  }
}

