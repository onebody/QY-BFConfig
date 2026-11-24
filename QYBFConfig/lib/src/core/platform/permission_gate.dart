import "package:permission_handler/permission_handler.dart";

/// Requests the runtime permissions needed to scan/connect over BLE.
/// Abstracted so the controller is testable without the plugin.
abstract interface class PermissionGate {
  Future<bool> ensureBle();
}

final class PermissionHandlerGate implements PermissionGate {
  const PermissionHandlerGate();

  @override
  Future<bool> ensureBle() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      // Android 10/11 require location for scanning; ignored on 12+.
      Permission.locationWhenInUse,
    ].request();

    final scan = statuses[Permission.bluetoothScan];
    final connect = statuses[Permission.bluetoothConnect];
    return (scan?.isGranted ?? false) && (connect?.isGranted ?? false);
  }
}
