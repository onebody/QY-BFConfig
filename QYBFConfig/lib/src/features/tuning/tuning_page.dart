import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "debug_tuning_controller.dart";

class TuningPage extends ConsumerWidget {
  const TuningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(debugTuningControllerProvider);
    final controller = ref.read(debugTuningControllerProvider.notifier);
    final totalParameters = debugTuningCatalog.fold<int>(
      0,
      (sum, module) => sum + module.parameters.length,
    );
    final activeModule = state.activeModule;
    final activeDescriptor = debugTuningCatalog.firstWhere(
      (module) => module.module == activeModule,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WorkspaceHeader(
          totalParameters: totalParameters,
          state: state,
          onResetAll: controller.resetAll,
          onModeChanged: controller.setUserMode,
        ),
        const SizedBox(height: 16),
        _ModuleRail(
          activeModule: activeModule,
          onChanged: controller.setActiveModule,
        ),
        const SizedBox(height: 16),
        if (state.userMode == DebugUserMode.advanced) ...[
          _RealtimeSummary(
            module: activeModule,
            state: state,
            parameterCount: activeDescriptor.parameters.length,
          ),
          const SizedBox(height: 16),
          _ModulePanel(module: activeDescriptor),
        ] else
          _StreamlinedPlaceholder(activeModule: activeModule),
        const SizedBox(height: 16),
        _ChangeLogPanel(entries: state.changeLog),
      ],
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.totalParameters,
    required this.state,
    required this.onResetAll,
    required this.onModeChanged,
  });

  final int totalParameters;
  final DebugTuningState state;
  final VoidCallback onResetAll;
  final ValueChanged<DebugUserMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("专业调参工作台", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              "界面调整为更接近专业调参工具的工作流：模块先行、状态常驻、参数集中、修改即时生效。",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SegmentedButton<DebugUserMode>(
              segments: const [
                ButtonSegment(
                  value: DebugUserMode.advanced,
                  icon: Icon(Icons.tune),
                  label: Text("高级"),
                ),
                ButtonSegment(
                  value: DebugUserMode.streamlined,
                  icon: Icon(Icons.person_outline),
                  label: Text("精简"),
                ),
              ],
              selected: {state.userMode},
              onSelectionChanged: (selection) {
                onModeChanged(selection.first);
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text("模块 ${debugTuningCatalog.length}")),
                Chip(label: Text("参数 $totalParameters")),
                Chip(label: Text("日志 ${state.changeLog.length}")),
                Chip(
                  avatar: const Icon(Icons.usb, size: 18),
                  label: Text("链路 ${state.preferredLink.toUpperCase()}"),
                ),
                Chip(label: Text("超时 ${state.requestTimeoutMs}ms")),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: const Key("resetAllButton"),
                    onPressed: onResetAll,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text("全部恢复默认"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleRail extends StatelessWidget {
  const _ModuleRail({required this.activeModule, required this.onChanged});

  final DebugTuningModule activeModule;
  final ValueChanged<DebugTuningModule> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: debugTuningCatalog
            .map(
              (module) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: Key("module-${module.module.name}"),
                  label: Text(module.module.title),
                  selected: module.module == activeModule,
                  onSelected: (_) => onChanged(module.module),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _RealtimeSummary extends StatelessWidget {
  const _RealtimeSummary({
    required this.module,
    required this.state,
    required this.parameterCount,
  });

  final DebugTuningModule module;
  final DebugTuningState state;
  final int parameterCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${module.title} · 当前工作区", style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(module.subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _summaryValues(
                module,
                state,
              ).map((item) => Chip(label: Text(item))).toList(growable: false),
            ),
            const SizedBox(height: 10),
            Text(
              "当前模块共 $parameterCount 项核心参数，采用高级调参与实时反馈布局。",
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  List<String> _summaryValues(
    DebugTuningModule module,
    DebugTuningState state,
  ) {
    return switch (module) {
      DebugTuningModule.connection => [
        "链路 ${state.preferredLink.toUpperCase()}",
        "日志 ${state.logLevel}",
        "自动重连 ${state.autoReconnect ? "开" : "关"}",
      ],
      DebugTuningModule.tuning => [
        "PID ${state.pidSensitivity.toStringAsFixed(2)}x",
        "滤波 ${state.filterStrength.toStringAsFixed(2)}",
        "Expo ${state.stickExpo.toStringAsFixed(2)}",
      ],
      DebugTuningModule.monitoring => [
        "图表 ${state.liveCharts ? "开启" : "关闭"}",
        "刷新 ${state.monitorRefreshHz}Hz",
        "告警 ${state.batteryWarningVoltage.toStringAsFixed(2)}V",
      ],
      DebugTuningModule.blackbox => [
        "采样 ${state.blackboxSampleRateHz}Hz",
        "叠层 ${state.blackboxOverlay ? "开启" : "关闭"}",
      ],
      DebugTuningModule.map => [
        "播放 ${state.mapPlaybackSpeed.toStringAsFixed(1)}x",
        "尾迹 ${state.mapTrailSeconds}s",
        "居中 ${state.mapAutoCenter ? "开启" : "关闭"}",
      ],
      DebugTuningModule.firmware => [
        "安全 ${state.firmwareSafeMode ? "开启" : "关闭"}",
        "分包 ${state.firmwareChunkSize}B",
        "校验 ${state.verifyAfterFlash ? "开启" : "关闭"}",
      ],
    };
  }
}

class _StreamlinedPlaceholder extends StatelessWidget {
  const _StreamlinedPlaceholder({required this.activeModule});

  final DebugTuningModule activeModule;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("精简模式规划中", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              "后续会围绕 `${activeModule.title}` 提供更少步骤、更少参数、更适合新手用户的操作流。当前先保留高级模式作为主工作台。",
            ),
          ],
        ),
      ),
    );
  }
}

class _ModulePanel extends ConsumerWidget {
  const _ModulePanel({required this.module});

  final DebugModuleDescriptor module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(debugTuningControllerProvider);
    final controller = ref.read(debugTuningControllerProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.module.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        module.module.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: Key("reset-${module.module.name}"),
                  onPressed: () => controller.resetModule(module.module),
                  icon: const Icon(Icons.undo),
                  label: const Text("重置模块"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: module.parameters
                  .map((parameter) => InputChip(label: Text(parameter.label)))
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            ...switch (module.module) {
              DebugTuningModule.connection => [
                _DropdownTile<String>(
                  label: "日志级别",
                  value: state.logLevel,
                  items: const ["trace", "debug", "info", "warn", "error"],
                  onChanged: controller.setLogLevel,
                ),
                _DropdownTile<String>(
                  label: "首选链路",
                  value: state.preferredLink,
                  items: const ["usb", "wifi", "ble"],
                  onChanged: controller.setPreferredLink,
                ),
                _SliderTile(
                  sliderKey: const Key("requestTimeoutSlider"),
                  label: "请求超时",
                  valueLabel: "${state.requestTimeoutMs}ms",
                  value: state.requestTimeoutMs.toDouble(),
                  min: 500,
                  max: 5000,
                  divisions: 18,
                  onChanged: controller.setRequestTimeoutMs,
                ),
                _SwitchTile(
                  tileKey: const Key("autoReconnectSwitch"),
                  label: "自动重连",
                  subtitle: state.autoReconnect ? "链路断开后自动恢复" : "保持手动重连模式",
                  value: state.autoReconnect,
                  onChanged: controller.setAutoReconnect,
                ),
              ],
              DebugTuningModule.tuning => [
                _SliderTile(
                  sliderKey: const Key("pidSensitivitySlider"),
                  label: "PID 灵敏度",
                  valueLabel: "${state.pidSensitivity.toStringAsFixed(2)}x",
                  value: state.pidSensitivity,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  onChanged: controller.setPidSensitivity,
                ),
                _SliderTile(
                  sliderKey: const Key("filterStrengthSlider"),
                  label: "滤波强度",
                  valueLabel: state.filterStrength.toStringAsFixed(2),
                  value: state.filterStrength,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  onChanged: controller.setFilterStrength,
                ),
                _SliderTile(
                  sliderKey: const Key("stickExpoSlider"),
                  label: "摇杆 Expo",
                  valueLabel: state.stickExpo.toStringAsFixed(2),
                  value: state.stickExpo,
                  min: 0.0,
                  max: 0.8,
                  divisions: 16,
                  onChanged: controller.setStickExpo,
                ),
              ],
              DebugTuningModule.monitoring => [
                _SwitchTile(
                  tileKey: const Key("liveChartsSwitch"),
                  label: "实时图表",
                  subtitle: state.liveCharts ? "波形图实时更新" : "只保留静态概览",
                  value: state.liveCharts,
                  onChanged: controller.setLiveCharts,
                ),
                _SliderTile(
                  sliderKey: const Key("monitorRefreshHzSlider"),
                  label: "刷新频率",
                  valueLabel: "${state.monitorRefreshHz}Hz",
                  value: state.monitorRefreshHz.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  onChanged: controller.setMonitorRefreshHz,
                ),
                _SliderTile(
                  sliderKey: const Key("batteryWarningVoltageSlider"),
                  label: "电压告警",
                  valueLabel:
                      "${state.batteryWarningVoltage.toStringAsFixed(2)}V",
                  value: state.batteryWarningVoltage,
                  min: 3.2,
                  max: 3.8,
                  divisions: 12,
                  onChanged: controller.setBatteryWarningVoltage,
                ),
              ],
              DebugTuningModule.blackbox => [
                _SliderTile(
                  sliderKey: const Key("blackboxSampleRateSlider"),
                  label: "采样频率",
                  valueLabel: "${state.blackboxSampleRateHz}Hz",
                  value: state.blackboxSampleRateHz.toDouble(),
                  min: 100,
                  max: 1000,
                  divisions: 18,
                  onChanged: controller.setBlackboxSampleRateHz,
                ),
                _SwitchTile(
                  tileKey: const Key("blackboxOverlaySwitch"),
                  label: "调试叠层",
                  subtitle: state.blackboxOverlay ? "显示关键事件辅助线" : "关闭叠层保持纯净视图",
                  value: state.blackboxOverlay,
                  onChanged: controller.setBlackboxOverlay,
                ),
              ],
              DebugTuningModule.map => [
                _SliderTile(
                  sliderKey: const Key("mapPlaybackSpeedSlider"),
                  label: "播放倍率",
                  valueLabel: "${state.mapPlaybackSpeed.toStringAsFixed(1)}x",
                  value: state.mapPlaybackSpeed,
                  min: 0.5,
                  max: 3.0,
                  divisions: 10,
                  onChanged: controller.setMapPlaybackSpeed,
                ),
                _SliderTile(
                  sliderKey: const Key("mapTrailSecondsSlider"),
                  label: "尾迹长度",
                  valueLabel: "${state.mapTrailSeconds}s",
                  value: state.mapTrailSeconds.toDouble(),
                  min: 10,
                  max: 120,
                  divisions: 11,
                  onChanged: controller.setMapTrailSeconds,
                ),
                _SwitchTile(
                  tileKey: const Key("mapAutoCenterSwitch"),
                  label: "自动居中",
                  subtitle: state.mapAutoCenter ? "轨迹点始终跟随画面中心" : "手动拖拽查看全程轨迹",
                  value: state.mapAutoCenter,
                  onChanged: controller.setMapAutoCenter,
                ),
              ],
              DebugTuningModule.firmware => [
                _SwitchTile(
                  tileKey: const Key("firmwareSafeModeSwitch"),
                  label: "安全刷写",
                  subtitle: state.firmwareSafeMode ? "优先保证稳定性" : "优先追求吞吐效率",
                  value: state.firmwareSafeMode,
                  onChanged: controller.setFirmwareSafeMode,
                ),
                _SliderTile(
                  sliderKey: const Key("firmwareChunkSizeSlider"),
                  label: "分包大小",
                  valueLabel: "${state.firmwareChunkSize}B",
                  value: state.firmwareChunkSize.toDouble(),
                  min: 128,
                  max: 1024,
                  divisions: 14,
                  onChanged: controller.setFirmwareChunkSize,
                ),
                _SwitchTile(
                  tileKey: const Key("verifyAfterFlashSwitch"),
                  label: "刷写后校验",
                  subtitle: state.verifyAfterFlash ? "刷写完成后自动校验" : "跳过校验以缩短流程",
                  value: state.verifyAfterFlash,
                  onChanged: controller.setVerifyAfterFlash,
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(item.toString()),
              ),
            )
            .toList(growable: false),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.sliderKey,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final Key sliderKey;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(valueLabel),
            ],
          ),
          Slider(
            key: sliderKey,
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.tileKey,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Key tileKey;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: tileKey,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ChangeLogPanel extends StatelessWidget {
  const _ChangeLogPanel({required this.entries});

  final List<DebugChangeLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("参数变更日志", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text("暂无变更记录，开始调整参数后会在这里实时留痕。")
            else
              ...entries
                  .take(10)
                  .map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text("${entry.module.title} · ${entry.parameter}"),
                      subtitle: Text("${entry.oldValue} -> ${entry.newValue}"),
                      trailing: Text(_formatTime(entry.timestamp)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, "0");
    final minute = value.minute.toString().padLeft(2, "0");
    final second = value.second.toString().padLeft(2, "0");
    return "$hour:$minute:$second";
  }
}
