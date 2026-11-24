import "dart:async";
import "dart:typed_data";

import "package:qy_msp/qy_msp.dart";

import "../link/link.dart";

final class MspClient {
  MspClient({
    required Link link,
    MspCodec? codec,
    Duration requestTimeout = const Duration(seconds: 2),
  })  : _link = link,
        _codec = codec ?? MspCodec(),
        _requestTimeout = requestTimeout;

  final Link _link;
  final MspCodec _codec;
  final Duration _requestTimeout;

  final _parser = MspParser();
  StreamSubscription<Uint8List>? _sub;

  final _pending = <int, Completer<MspFrame>>{};

  Future<void> start() async {
    _sub ??= _link.inbound.listen(_onBytes);
  }

  Future<void> stop() async {
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
  }

  Future<MspFrame> requestV1(
    int command, {
    Uint8List? payload,
  }) async {
    if (_pending.containsKey(command)) {
      throw StateError("duplicate in-flight request for command=$command");
    }

    final completer = Completer<MspFrame>();
    _pending[command] = completer;

    try {
      await _link.send(
        _codec.encode(
          MspFrame(
            version: MspVersion.v1,
            direction: MspDirection.toFlightController,
            command: command,
            payload: payload ?? Uint8List(0),
          ),
        ),
      );

      return await completer.future.timeout(_requestTimeout);
    } on TimeoutException catch (e) {
      throw TimeoutException("MSP request timeout: command=$command", e.duration);
    } finally {
      _pending.remove(command);
    }
  }

  void _onBytes(Uint8List chunk) {
    final frames = _parser.push(chunk);
    for (final frame in frames) {
      final completer = _pending[frame.command];
      if (completer != null && !completer.isCompleted) {
        completer.complete(frame);
      }
    }
  }
}
