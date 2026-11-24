import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/link/link.dart";
import "connection_controller.dart";

class ConnectionPage extends ConsumerWidget {
  const ConnectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectionControllerProvider);
    final controller = ref.read(connectionControllerProvider.notifier);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(
            state: state,
            onDisconnect: () => controller.disconnect(),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                state.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          _SectionHeader(
            title: "蓝牙设备",
            action: FilledButton.tonal(
              onPressed: () => state.scanning
                  ? controller.stopBleScan()
                  : controller.startBleScan(),
              child: Text(state.scanning ? "停止" : "扫描"),
            ),
          ),
          if (state.scanning && state.bleResults.isEmpty)
            const _Hint(text: "正在扫描…请确保飞控 BLE 已开启"),
          if (!state.scanning && state.bleResults.isEmpty)
            const _Hint(text: "暂无设备，点击“扫描”"),
          for (final entry in state.bleResults)
            Card(
              child: ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(entry.name),
                subtitle: Text("${entry.remoteId} · ${entry.rssi} dBm"),
                onTap: () => controller.connectBle(entry),
              ),
            ),
          _SectionHeader(
            title: "USB 设备",
            action: TextButton(
              onPressed: () => controller.refreshUsb(),
              child: const Text("刷新"),
            ),
          ),
          if (state.usbDevices.isEmpty)
            const _Hint(text: "未检测到 USB 串口设备"),
          for (final entry in state.usbDevices)
            Card(
              child: ListTile(
                leading: const Icon(Icons.usb),
                title: Text(entry.label),
                subtitle: Text("设备 #${entry.deviceId}"),
                onTap: () => controller.connectUsb(entry),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state, required this.onDisconnect});

  final ConnectionUiState state;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (state.linkState) {
      LinkState.disconnected => (
        Icons.link_off,
        "未连接",
      ),
      LinkState.connecting => (
        Icons.hourglass_top,
        "连接中…",
      ),
      LinkState.connected => (
        Icons.check_circle,
        "已连接 · ${_typeLabel(state.activeType)} ${state.activeLabel ?? ""}",
      ),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(text),
        trailing: state.linkState == LinkState.connected
            ? OutlinedButton(onPressed: onDisconnect, child: const Text("断开"))
            : null,
      ),
    );
  }

  static String _typeLabel(LinkType? type) => switch (type) {
    LinkType.ble => "蓝牙",
    LinkType.usb => "USB",
    LinkType.wifi => "WiFi",
    null => "",
  };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          action,
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
