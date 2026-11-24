import "package:usb_serial/usb_serial.dart";

/// A connected USB serial device, decoupled from the usb_serial plugin.
final class UsbDeviceEntry {
  const UsbDeviceEntry({required this.deviceId, required this.label});

  final int deviceId;
  final String label;
}

abstract interface class UsbDirectory {
  Future<List<UsbDeviceEntry>> list();
}

final class UsbSerialDirectory implements UsbDirectory {
  const UsbSerialDirectory();

  @override
  Future<List<UsbDeviceEntry>> list() async {
    final devices = await UsbSerial.listDevices();
    return devices
        .map(
          (d) => UsbDeviceEntry(
            deviceId: d.deviceId ?? 0,
            label: d.productName ??
                d.manufacturerName ??
                "USB ${d.vid?.toRadixString(16) ?? "?"}",
          ),
        )
        .toList(growable: false);
  }
}
