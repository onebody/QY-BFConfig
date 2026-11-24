import "dart:async";

import "package:flutter_blue_plus/flutter_blue_plus.dart";

/// A discovered BLE device, decoupled from flutter_blue_plus so the
/// controller can be unit-tested.
final class BleScanEntry {
  const BleScanEntry({
    required this.remoteId,
    required this.name,
    required this.rssi,
  });

  final String remoteId;
  final String name;
  final int rssi;
}

/// Emits the cumulative list of scan results while scanning.
abstract interface class BleScanner {
  Stream<List<BleScanEntry>> get results;
  Future<void> start();
  Future<void> stop();
}

final class FlutterBluePlusBleScanner implements BleScanner {
  FlutterBluePlusBleScanner({
    this.scanTimeout = const Duration(seconds: 12),
  });

  final Duration scanTimeout;

  @override
  Stream<List<BleScanEntry>> get results =>
      FlutterBluePlus.scanResults.map((results) {
        return results
            .map(
              (r) => BleScanEntry(
                remoteId: r.device.remoteId.str,
                name: r.advertisementData.advName.isNotEmpty
                    ? r.advertisementData.advName
                    : r.device.remoteId.str,
                rssi: r.rssi,
              ),
            )
            .toList(growable: false);
      });

  @override
  Future<void> start() {
    return FlutterBluePlus.startScan(
      timeout: scanTimeout,
      androidUsesFineLocation: true,
    );
  }

  @override
  Future<void> stop() => FlutterBluePlus.stopScan();
}
