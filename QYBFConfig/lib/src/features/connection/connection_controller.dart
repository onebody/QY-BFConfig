import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/link/ble_link.dart";
import "../../core/link/ble_scan.dart";
import "../../core/link/link.dart";
import "../../core/link/usb_directory.dart";
import "../../core/link/usb_link.dart";
import "../../core/platform/permission_gate.dart";
import "../../core/link/ble_flutter_blue_transport.dart";
import "../../core/link/usb_serial_transport.dart";

final permissionGateProvider = Provider<PermissionGate>(
  (ref) => const PermissionHandlerGate(),
);

final bleScannerProvider = Provider<BleScanner>(
  (ref) => FlutterBluePlusBleScanner(),
);

final bleTransportProvider = Provider<BleTransport>(
  (ref) => FlutterBluePlusBleTransport(),
);

final usbDirectoryProvider = Provider<UsbDirectory>(
  (ref) => const UsbSerialDirectory(),
);

final usbTransportProvider = Provider<SerialTransport>(
  (ref) => const UsbSerialTransport(),
);

final connectionControllerProvider =
    NotifierProvider<ConnectionController, ConnectionUiState>(
      ConnectionController.new,
    );

const _unset = Object();

class ConnectionUiState {
  const ConnectionUiState({
    this.linkState = LinkState.disconnected,
    this.activeType,
    this.activeLabel,
    this.scanning = false,
    this.bleResults = const [],
    this.usbDevices = const [],
    this.error,
  });

  final LinkState linkState;
  final LinkType? activeType;
  final String? activeLabel;
  final bool scanning;
  final List<BleScanEntry> bleResults;
  final List<UsbDeviceEntry> usbDevices;
  final String? error;

  ConnectionUiState copyWith({
    LinkState? linkState,
    Object? activeType = _unset,
    Object? activeLabel = _unset,
    bool? scanning,
    List<BleScanEntry>? bleResults,
    List<UsbDeviceEntry>? usbDevices,
    Object? error = _unset,
  }) {
    return ConnectionUiState(
      linkState: linkState ?? this.linkState,
      activeType: activeType == _unset
          ? this.activeType
          : activeType as LinkType?,
      activeLabel: activeLabel == _unset
          ? this.activeLabel
          : activeLabel as String?,
      scanning: scanning ?? this.scanning,
      bleResults: bleResults ?? this.bleResults,
      usbDevices: usbDevices ?? this.usbDevices,
      error: error == _unset ? this.error : error as String?,
    );
  }
}

class ConnectionController extends Notifier<ConnectionUiState> {
  PermissionGate get _gate => ref.read(permissionGateProvider);
  BleScanner get _scanner => ref.read(bleScannerProvider);
  BleTransport get _bleTransport => ref.read(bleTransportProvider);
  UsbDirectory get _usbDirectory => ref.read(usbDirectoryProvider);
  SerialTransport get _usbTransport => ref.read(usbTransportProvider);

  Link? _activeLink;
  StreamSubscription<LinkState>? _linkStateSub;
  StreamSubscription<List<BleScanEntry>>? _scanSub;

  LinkType? _pendingType;
  String? _pendingLabel;

  Link? get currentLink => _activeLink;

  @override
  ConnectionUiState build() {
    ref.onDispose(() {
      _linkStateSub?.cancel();
      _scanSub?.cancel();
      _activeLink?.disconnect();
    });
    return const ConnectionUiState();
  }

  Future<void> startBleScan() async {
    state = state.copyWith(scanning: true, bleResults: const [], error: null);
    _scanSub ??= _scanner.results.listen((entries) {
      state = state.copyWith(bleResults: entries);
    });
    try {
      await _scanner.start();
    } on Object catch (e) {
      _scanSub?.cancel();
      _scanSub = null;
      state = state.copyWith(scanning: false, error: _describe(e));
    }
  }

  Future<void> stopBleScan() async {
    await _scanner.stop();
    _scanSub?.cancel();
    _scanSub = null;
    state = state.copyWith(scanning: false);
  }

  Future<void> refreshUsb() async {
    final devices = await _usbDirectory.list();
    state = state.copyWith(usbDevices: devices);
  }

  Future<void> connectBle(BleScanEntry entry) async {
    if (!await _gate.ensureBle()) {
      state = state.copyWith(
        error: "缺少蓝牙权限，请在系统设置中授权后重试",
      );
      return;
    }
    await _connect(
      () => BleLink(remoteId: entry.remoteId, transport: _bleTransport),
      type: LinkType.ble,
      label: entry.name,
    );
  }

  Future<void> connectUsb(UsbDeviceEntry entry) async {
    await _connect(
      () => UsbLink(deviceId: entry.deviceId, transport: _usbTransport),
      type: LinkType.usb,
      label: entry.label,
    );
  }

  Future<void> disconnect() async {
    await _teardownActiveLink();
    state = state.copyWith(
      linkState: LinkState.disconnected,
      activeType: null,
      activeLabel: null,
    );
  }

  Future<void> _connect(
    Link Function() factory, {
    required LinkType type,
    required String label,
  }) async {
    await _teardownActiveLink();
    final link = factory();
    _pendingType = type;
    _pendingLabel = label;
    _linkStateSub = link.states.listen(_onLinkState);
    state = state.copyWith(linkState: LinkState.connecting, error: null);
    try {
      await link.connect();
      _activeLink = link;
    } on Object catch (e) {
      // cancel is synchronous for these controllers; awaiting it never
      // completes under flutter_test's fake async.
      _linkStateSub?.cancel();
      _linkStateSub = null;
      try {
        await link.disconnect();
      } on Object {
        // best effort
      }
      _activeLink = null;
      state = state.copyWith(
        linkState: LinkState.disconnected,
        activeType: null,
        activeLabel: null,
        error: _describe(e),
      );
    }
  }

  void _onLinkState(LinkState next) {
    if (next == LinkState.connected) {
      state = state.copyWith(
        linkState: next,
        activeType: _pendingType,
        activeLabel: _pendingLabel,
      );
    } else if (next == LinkState.disconnected) {
      state = state.copyWith(
        linkState: next,
        activeType: null,
        activeLabel: null,
      );
      _activeLink = null;
    } else {
      state = state.copyWith(linkState: next);
    }
  }

  Future<void> _teardownActiveLink() async {
    _linkStateSub?.cancel();
    _linkStateSub = null;
    final link = _activeLink;
    _activeLink = null;
    if (link != null) {
      await link.disconnect();
    }
  }

  String _describe(Object e) {
    if (e is LinkException) {
      final cause = e.cause;
      return cause == null ? e.message : "${e.message}: $cause";
    }
    return e.toString();
  }
}
