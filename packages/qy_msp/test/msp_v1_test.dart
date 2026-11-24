import "dart:typed_data";

import "package:qy_msp/qy_msp.dart";
import "package:test/test.dart";

void main() {
  test("encode v1 request without payload", () {
    final codec = MspCodec();
    final bytes = codec.encode(
      MspFrame(
        version: MspVersion.v1,
        direction: MspDirection.toFlightController,
        command: 0x64,
        payload: Uint8List(0),
      ),
    );

    expect(bytes, Uint8List.fromList([0x24, 0x4D, 0x3C, 0x00, 0x64, 0x64]));
  });

  test("parser v1 ok response with payload", () {
    final parser = MspParser();
    final payload = Uint8List.fromList([0x01, 0x02, 0x03]);

    final codec = MspCodec();
    final encoded = codec.encode(
      MspFrame(
        version: MspVersion.v1,
        direction: MspDirection.fromFlightController,
        command: 0x10,
        payload: payload,
      ),
    );

    final frames = parser.push(encoded);
    expect(frames, hasLength(1));
    expect(frames.single.command, 0x10);
    expect(frames.single.payload, payload);
    expect(frames.single.status, MspV1Status.ok);
  });

  test("parser handles chunked frames", () {
    final parser = MspParser();
    final codec = MspCodec();
    final encoded = codec.encode(
      MspFrame(
        version: MspVersion.v1,
        direction: MspDirection.toFlightController,
        command: 0x01,
        payload: Uint8List.fromList([0xAA, 0xBB]),
      ),
    );

    final part1 = Uint8List.sublistView(encoded, 0, 4);
    final part2 = Uint8List.sublistView(encoded, 4);

    expect(parser.push(part1), isEmpty);
    final frames = parser.push(part2);
    expect(frames, hasLength(1));
    expect(frames.single.command, 0x01);
    expect(frames.single.payload, Uint8List.fromList([0xAA, 0xBB]));
  });
}

