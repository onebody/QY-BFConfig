import "package:flutter_riverpod/flutter_riverpod.dart";

enum DebugTuningModule {
  connection,
  tuning,
  monitoring,
  blackbox,
  map,
  firmware,
}

enum DebugUserMode { advanced, streamlined }

extension DebugUserModeX on DebugUserMode {
  String get title => switch (this) {
    DebugUserMode.advanced => "高级模式",
    DebugUserMode.streamlined => "精简模式",
  };
}

extension DebugTuningModuleX on DebugTuningModule {
  String get title => switch (this) {
    DebugTuningModule.connection => "连接链路",
    DebugTuningModule.tuning => "飞控调参",
    DebugTuningModule.monitoring => "运行监测",
    DebugTuningModule.blackbox => "黑匣子",
    DebugTuningModule.map => "地图回放",
    DebugTuningModule.firmware => "固件升级",
  };

  String get subtitle => switch (this) {
    DebugTuningModule.connection => "覆盖链路优先级、请求时延与自动重连策略。",
    DebugTuningModule.tuning => "模拟 PID、滤波与摇杆曲线等核心调参参数。",
    DebugTuningModule.monitoring => "控制监测刷新频率、电池告警与图表开关。",
    DebugTuningModule.blackbox => "模拟黑匣子采样与调试叠层展示策略。",
    DebugTuningModule.map => "控制轨迹播放速度、尾迹长度与自动居中。",
    DebugTuningModule.firmware => "模拟分包刷写、安全模式与校验策略。",
  };
}

class DebugParameterDescriptor {
  const DebugParameterDescriptor({
    required this.key,
    required this.label,
    required this.description,
    required this.defaultValue,
  });

  final String key;
  final String label;
  final String description;
  final String defaultValue;
}

class DebugModuleDescriptor {
  const DebugModuleDescriptor({required this.module, required this.parameters});

  final DebugTuningModule module;
  final List<DebugParameterDescriptor> parameters;
}

const debugTuningCatalog = <DebugModuleDescriptor>[
  DebugModuleDescriptor(
    module: DebugTuningModule.connection,
    parameters: [
      DebugParameterDescriptor(
        key: "logLevel",
        label: "日志级别",
        description: "控制调试期的日志详细程度。",
        defaultValue: "info",
      ),
      DebugParameterDescriptor(
        key: "preferredLink",
        label: "首选链路",
        description: "决定 USB / WiFi / BLE 的优先连接顺序。",
        defaultValue: "usb",
      ),
      DebugParameterDescriptor(
        key: "requestTimeoutMs",
        label: "请求超时",
        description: "MSP 调试请求的超时时间。",
        defaultValue: "2000ms",
      ),
      DebugParameterDescriptor(
        key: "autoReconnect",
        label: "自动重连",
        description: "链路中断后是否自动恢复。",
        defaultValue: "开启",
      ),
    ],
  ),
  DebugModuleDescriptor(
    module: DebugTuningModule.tuning,
    parameters: [
      DebugParameterDescriptor(
        key: "pidSensitivity",
        label: "PID 灵敏度",
        description: "控制姿态修正的整体响应强度。",
        defaultValue: "1.00x",
      ),
      DebugParameterDescriptor(
        key: "filterStrength",
        label: "滤波强度",
        description: "平衡抖动抑制与操控延迟。",
        defaultValue: "0.50",
      ),
      DebugParameterDescriptor(
        key: "stickExpo",
        label: "摇杆 Expo",
        description: "模拟摇杆中心区灵敏度曲线。",
        defaultValue: "0.30",
      ),
    ],
  ),
  DebugModuleDescriptor(
    module: DebugTuningModule.monitoring,
    parameters: [
      DebugParameterDescriptor(
        key: "liveCharts",
        label: "实时图表",
        description: "控制监测页是否显示动态曲线。",
        defaultValue: "开启",
      ),
      DebugParameterDescriptor(
        key: "monitorRefreshHz",
        label: "刷新频率",
        description: "监测面板每秒刷新次数。",
        defaultValue: "10Hz",
      ),
      DebugParameterDescriptor(
        key: "batteryWarningVoltage",
        label: "电压告警",
        description: "模拟低电压告警阈值。",
        defaultValue: "3.50V",
      ),
    ],
  ),
  DebugModuleDescriptor(
    module: DebugTuningModule.blackbox,
    parameters: [
      DebugParameterDescriptor(
        key: "blackboxSampleRateHz",
        label: "采样频率",
        description: "黑匣子事件的采样速率。",
        defaultValue: "500Hz",
      ),
      DebugParameterDescriptor(
        key: "blackboxOverlay",
        label: "调试叠层",
        description: "是否在分析界面显示调试辅助标记。",
        defaultValue: "开启",
      ),
    ],
  ),
  DebugModuleDescriptor(
    module: DebugTuningModule.map,
    parameters: [
      DebugParameterDescriptor(
        key: "mapPlaybackSpeed",
        label: "播放倍率",
        description: "地图轨迹回放的播放速度。",
        defaultValue: "1.0x",
      ),
      DebugParameterDescriptor(
        key: "mapTrailSeconds",
        label: "尾迹长度",
        description: "地图上保留的历史轨迹秒数。",
        defaultValue: "30s",
      ),
      DebugParameterDescriptor(
        key: "mapAutoCenter",
        label: "自动居中",
        description: "轨迹播放时是否自动跟随当前位置。",
        defaultValue: "开启",
      ),
    ],
  ),
  DebugModuleDescriptor(
    module: DebugTuningModule.firmware,
    parameters: [
      DebugParameterDescriptor(
        key: "firmwareSafeMode",
        label: "安全刷写",
        description: "开启后降低传输风险并放慢吞吐。",
        defaultValue: "开启",
      ),
      DebugParameterDescriptor(
        key: "firmwareChunkSize",
        label: "分包大小",
        description: "单次固件传输的分包大小。",
        defaultValue: "256B",
      ),
      DebugParameterDescriptor(
        key: "verifyAfterFlash",
        label: "刷写后校验",
        description: "刷写结束后是否执行完整校验。",
        defaultValue: "开启",
      ),
    ],
  ),
];

class DebugChangeLogEntry {
  const DebugChangeLogEntry({
    required this.module,
    required this.parameter,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
  });

  final DebugTuningModule module;
  final String parameter;
  final String oldValue;
  final String newValue;
  final DateTime timestamp;
}

class DebugTuningState {
  const DebugTuningState({
    required this.userMode,
    required this.activeModule,
    required this.logLevel,
    required this.preferredLink,
    required this.requestTimeoutMs,
    required this.autoReconnect,
    required this.pidSensitivity,
    required this.filterStrength,
    required this.stickExpo,
    required this.liveCharts,
    required this.monitorRefreshHz,
    required this.batteryWarningVoltage,
    required this.blackboxSampleRateHz,
    required this.blackboxOverlay,
    required this.mapPlaybackSpeed,
    required this.mapTrailSeconds,
    required this.mapAutoCenter,
    required this.firmwareSafeMode,
    required this.firmwareChunkSize,
    required this.verifyAfterFlash,
    required this.changeLog,
  });

  factory DebugTuningState.defaults() {
    return const DebugTuningState(
      userMode: DebugUserMode.advanced,
      activeModule: DebugTuningModule.tuning,
      logLevel: "info",
      preferredLink: "usb",
      requestTimeoutMs: 2000,
      autoReconnect: true,
      pidSensitivity: 1.0,
      filterStrength: 0.5,
      stickExpo: 0.3,
      liveCharts: true,
      monitorRefreshHz: 10,
      batteryWarningVoltage: 3.5,
      blackboxSampleRateHz: 500,
      blackboxOverlay: true,
      mapPlaybackSpeed: 1.0,
      mapTrailSeconds: 30,
      mapAutoCenter: true,
      firmwareSafeMode: true,
      firmwareChunkSize: 256,
      verifyAfterFlash: true,
      changeLog: [],
    );
  }

  final DebugUserMode userMode;
  final DebugTuningModule activeModule;
  final String logLevel;
  final String preferredLink;
  final int requestTimeoutMs;
  final bool autoReconnect;
  final double pidSensitivity;
  final double filterStrength;
  final double stickExpo;
  final bool liveCharts;
  final int monitorRefreshHz;
  final double batteryWarningVoltage;
  final int blackboxSampleRateHz;
  final bool blackboxOverlay;
  final double mapPlaybackSpeed;
  final int mapTrailSeconds;
  final bool mapAutoCenter;
  final bool firmwareSafeMode;
  final int firmwareChunkSize;
  final bool verifyAfterFlash;
  final List<DebugChangeLogEntry> changeLog;

  DebugTuningState copyWith({
    DebugUserMode? userMode,
    DebugTuningModule? activeModule,
    String? logLevel,
    String? preferredLink,
    int? requestTimeoutMs,
    bool? autoReconnect,
    double? pidSensitivity,
    double? filterStrength,
    double? stickExpo,
    bool? liveCharts,
    int? monitorRefreshHz,
    double? batteryWarningVoltage,
    int? blackboxSampleRateHz,
    bool? blackboxOverlay,
    double? mapPlaybackSpeed,
    int? mapTrailSeconds,
    bool? mapAutoCenter,
    bool? firmwareSafeMode,
    int? firmwareChunkSize,
    bool? verifyAfterFlash,
    List<DebugChangeLogEntry>? changeLog,
  }) {
    return DebugTuningState(
      userMode: userMode ?? this.userMode,
      activeModule: activeModule ?? this.activeModule,
      logLevel: logLevel ?? this.logLevel,
      preferredLink: preferredLink ?? this.preferredLink,
      requestTimeoutMs: requestTimeoutMs ?? this.requestTimeoutMs,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      pidSensitivity: pidSensitivity ?? this.pidSensitivity,
      filterStrength: filterStrength ?? this.filterStrength,
      stickExpo: stickExpo ?? this.stickExpo,
      liveCharts: liveCharts ?? this.liveCharts,
      monitorRefreshHz: monitorRefreshHz ?? this.monitorRefreshHz,
      batteryWarningVoltage:
          batteryWarningVoltage ?? this.batteryWarningVoltage,
      blackboxSampleRateHz: blackboxSampleRateHz ?? this.blackboxSampleRateHz,
      blackboxOverlay: blackboxOverlay ?? this.blackboxOverlay,
      mapPlaybackSpeed: mapPlaybackSpeed ?? this.mapPlaybackSpeed,
      mapTrailSeconds: mapTrailSeconds ?? this.mapTrailSeconds,
      mapAutoCenter: mapAutoCenter ?? this.mapAutoCenter,
      firmwareSafeMode: firmwareSafeMode ?? this.firmwareSafeMode,
      firmwareChunkSize: firmwareChunkSize ?? this.firmwareChunkSize,
      verifyAfterFlash: verifyAfterFlash ?? this.verifyAfterFlash,
      changeLog: changeLog ?? this.changeLog,
    );
  }
}

final debugTuningControllerProvider =
    NotifierProvider<DebugTuningController, DebugTuningState>(
      DebugTuningController.new,
    );

class DebugTuningController extends Notifier<DebugTuningState> {
  static const _maxLogEntries = 60;

  @override
  DebugTuningState build() => DebugTuningState.defaults();

  void setUserMode(DebugUserMode mode) {
    state = state.copyWith(userMode: mode);
  }

  void setActiveModule(DebugTuningModule module) {
    state = state.copyWith(activeModule: module);
  }

  void setLogLevel(String value) {
    _commit(
      module: DebugTuningModule.connection,
      parameter: "日志级别",
      oldValue: state.logLevel,
      newValue: value,
      next: state.copyWith(logLevel: value),
    );
  }

  void setPreferredLink(String value) {
    _commit(
      module: DebugTuningModule.connection,
      parameter: "首选链路",
      oldValue: state.preferredLink,
      newValue: value,
      next: state.copyWith(preferredLink: value),
    );
  }

  void setRequestTimeoutMs(double value) {
    final nextValue = value.round();
    _commit(
      module: DebugTuningModule.connection,
      parameter: "请求超时",
      oldValue: "${state.requestTimeoutMs}ms",
      newValue: "${nextValue}ms",
      next: state.copyWith(requestTimeoutMs: nextValue),
    );
  }

  void setAutoReconnect(bool value) {
    _commit(
      module: DebugTuningModule.connection,
      parameter: "自动重连",
      oldValue: _boolLabel(state.autoReconnect),
      newValue: _boolLabel(value),
      next: state.copyWith(autoReconnect: value),
    );
  }

  void setPidSensitivity(double value) {
    _commit(
      module: DebugTuningModule.tuning,
      parameter: "PID 灵敏度",
      oldValue: _doubleLabel(state.pidSensitivity, suffix: "x"),
      newValue: _doubleLabel(value, suffix: "x"),
      next: state.copyWith(pidSensitivity: value),
    );
  }

  void setFilterStrength(double value) {
    _commit(
      module: DebugTuningModule.tuning,
      parameter: "滤波强度",
      oldValue: _doubleLabel(state.filterStrength),
      newValue: _doubleLabel(value),
      next: state.copyWith(filterStrength: value),
    );
  }

  void setStickExpo(double value) {
    _commit(
      module: DebugTuningModule.tuning,
      parameter: "摇杆 Expo",
      oldValue: _doubleLabel(state.stickExpo),
      newValue: _doubleLabel(value),
      next: state.copyWith(stickExpo: value),
    );
  }

  void setLiveCharts(bool value) {
    _commit(
      module: DebugTuningModule.monitoring,
      parameter: "实时图表",
      oldValue: _boolLabel(state.liveCharts),
      newValue: _boolLabel(value),
      next: state.copyWith(liveCharts: value),
    );
  }

  void setMonitorRefreshHz(double value) {
    final nextValue = value.round();
    _commit(
      module: DebugTuningModule.monitoring,
      parameter: "刷新频率",
      oldValue: "${state.monitorRefreshHz}Hz",
      newValue: "${nextValue}Hz",
      next: state.copyWith(monitorRefreshHz: nextValue),
    );
  }

  void setBatteryWarningVoltage(double value) {
    _commit(
      module: DebugTuningModule.monitoring,
      parameter: "电压告警",
      oldValue: _doubleLabel(state.batteryWarningVoltage, suffix: "V"),
      newValue: _doubleLabel(value, suffix: "V"),
      next: state.copyWith(batteryWarningVoltage: value),
    );
  }

  void setBlackboxSampleRateHz(double value) {
    final nextValue = value.round();
    _commit(
      module: DebugTuningModule.blackbox,
      parameter: "采样频率",
      oldValue: "${state.blackboxSampleRateHz}Hz",
      newValue: "${nextValue}Hz",
      next: state.copyWith(blackboxSampleRateHz: nextValue),
    );
  }

  void setBlackboxOverlay(bool value) {
    _commit(
      module: DebugTuningModule.blackbox,
      parameter: "调试叠层",
      oldValue: _boolLabel(state.blackboxOverlay),
      newValue: _boolLabel(value),
      next: state.copyWith(blackboxOverlay: value),
    );
  }

  void setMapPlaybackSpeed(double value) {
    _commit(
      module: DebugTuningModule.map,
      parameter: "播放倍率",
      oldValue: _doubleLabel(state.mapPlaybackSpeed, suffix: "x"),
      newValue: _doubleLabel(value, suffix: "x"),
      next: state.copyWith(mapPlaybackSpeed: value),
    );
  }

  void setMapTrailSeconds(double value) {
    final nextValue = value.round();
    _commit(
      module: DebugTuningModule.map,
      parameter: "尾迹长度",
      oldValue: "${state.mapTrailSeconds}s",
      newValue: "${nextValue}s",
      next: state.copyWith(mapTrailSeconds: nextValue),
    );
  }

  void setMapAutoCenter(bool value) {
    _commit(
      module: DebugTuningModule.map,
      parameter: "自动居中",
      oldValue: _boolLabel(state.mapAutoCenter),
      newValue: _boolLabel(value),
      next: state.copyWith(mapAutoCenter: value),
    );
  }

  void setFirmwareSafeMode(bool value) {
    _commit(
      module: DebugTuningModule.firmware,
      parameter: "安全刷写",
      oldValue: _boolLabel(state.firmwareSafeMode),
      newValue: _boolLabel(value),
      next: state.copyWith(firmwareSafeMode: value),
    );
  }

  void setFirmwareChunkSize(double value) {
    final nextValue = value.round();
    _commit(
      module: DebugTuningModule.firmware,
      parameter: "分包大小",
      oldValue: "${state.firmwareChunkSize}B",
      newValue: "${nextValue}B",
      next: state.copyWith(firmwareChunkSize: nextValue),
    );
  }

  void setVerifyAfterFlash(bool value) {
    _commit(
      module: DebugTuningModule.firmware,
      parameter: "刷写后校验",
      oldValue: _boolLabel(state.verifyAfterFlash),
      newValue: _boolLabel(value),
      next: state.copyWith(verifyAfterFlash: value),
    );
  }

  void resetModule(DebugTuningModule module) {
    final defaults = DebugTuningState.defaults();
    state = switch (module) {
      DebugTuningModule.connection => state.copyWith(
        logLevel: defaults.logLevel,
        preferredLink: defaults.preferredLink,
        requestTimeoutMs: defaults.requestTimeoutMs,
        autoReconnect: defaults.autoReconnect,
        changeLog: _prependLog(
          module: module,
          parameter: "模块重置",
          oldValue: "自定义值",
          newValue: "默认值",
        ),
      ),
      DebugTuningModule.tuning => state.copyWith(
        pidSensitivity: defaults.pidSensitivity,
        filterStrength: defaults.filterStrength,
        stickExpo: defaults.stickExpo,
        changeLog: _prependLog(
          module: module,
          parameter: "模块重置",
          oldValue: "自定义值",
          newValue: "默认值",
        ),
      ),
      DebugTuningModule.monitoring => state.copyWith(
        liveCharts: defaults.liveCharts,
        monitorRefreshHz: defaults.monitorRefreshHz,
        batteryWarningVoltage: defaults.batteryWarningVoltage,
        changeLog: _prependLog(
          module: module,
          parameter: "模块重置",
          oldValue: "自定义值",
          newValue: "默认值",
        ),
      ),
      DebugTuningModule.blackbox => state.copyWith(
        blackboxSampleRateHz: defaults.blackboxSampleRateHz,
        blackboxOverlay: defaults.blackboxOverlay,
        changeLog: _prependLog(
          module: module,
          parameter: "模块重置",
          oldValue: "自定义值",
          newValue: "默认值",
        ),
      ),
      DebugTuningModule.map => state.copyWith(
        mapPlaybackSpeed: defaults.mapPlaybackSpeed,
        mapTrailSeconds: defaults.mapTrailSeconds,
        mapAutoCenter: defaults.mapAutoCenter,
        changeLog: _prependLog(
          module: module,
          parameter: "模块重置",
          oldValue: "自定义值",
          newValue: "默认值",
        ),
      ),
      DebugTuningModule.firmware => state.copyWith(
        firmwareSafeMode: defaults.firmwareSafeMode,
        firmwareChunkSize: defaults.firmwareChunkSize,
        verifyAfterFlash: defaults.verifyAfterFlash,
        changeLog: _prependLog(
          module: module,
          parameter: "模块重置",
          oldValue: "自定义值",
          newValue: "默认值",
        ),
      ),
    };
  }

  void resetAll() {
    final previousLog = state.changeLog;
    state = DebugTuningState.defaults().copyWith(
      changeLog: [
        DebugChangeLogEntry(
          module: DebugTuningModule.tuning,
          parameter: "全部参数",
          oldValue: "当前调试值",
          newValue: "默认值",
          timestamp: DateTime.now(),
        ),
        ...previousLog,
      ].take(_maxLogEntries).toList(growable: false),
    );
  }

  void _commit({
    required DebugTuningModule module,
    required String parameter,
    required String oldValue,
    required String newValue,
    required DebugTuningState next,
  }) {
    if (oldValue == newValue) {
      return;
    }

    state = next.copyWith(
      changeLog: _prependLog(
        module: module,
        parameter: parameter,
        oldValue: oldValue,
        newValue: newValue,
      ),
    );
  }

  List<DebugChangeLogEntry> _prependLog({
    required DebugTuningModule module,
    required String parameter,
    required String oldValue,
    required String newValue,
  }) {
    return [
      DebugChangeLogEntry(
        module: module,
        parameter: parameter,
        oldValue: oldValue,
        newValue: newValue,
        timestamp: DateTime.now(),
      ),
      ...state.changeLog,
    ].take(_maxLogEntries).toList(growable: false);
  }

  String _doubleLabel(double value, {String suffix = ""}) {
    return "${value.toStringAsFixed(2)}$suffix";
  }

  String _boolLabel(bool value) => value ? "开启" : "关闭";
}
