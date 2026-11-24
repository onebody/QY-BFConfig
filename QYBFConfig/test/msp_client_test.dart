import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:qy_msp/qy_msp.dart";

import "package:qybfconfig/src/core/link/in_memory_link.dart";
import "package:qybfconfig/src/core/link/link.dart";
import "package:qybfconfig/src/core/msp/msp_client.dart";

void main() {
  test("msp client request/response", () async {
    final link = InMemoryLink(type: LinkType.usb);
    await link.connect();

    final client = MspClient(link: link);
    await client.start();

    final codec = MspCodec();
    final outboundSub = link.outbound.listen((bytes) {
      final parsed = MspParser().push(bytes);
      expect(parsed, hasLength(1));
      expect(parsed.single.command, 0x10);

      final response = codec.encode(
        MspFrame(
          version: MspVersion.v1,
          direction: MspDirection.fromFlightController,
          command: 0x10,
          payload: Uint8List.fromList([0x01, 0x02]),
        ),
      );
      link.pushInbound(response);
    });

    final frame = await client.requestV1(0x10);
    expect(frame.payload, Uint8List.fromList([0x01, 0x02]));

    await outboundSub.cancel();
    await client.stop();
    await link.dispose();
  });
}

