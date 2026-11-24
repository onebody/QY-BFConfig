import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../tuning/debug_tuning_controller.dart";

class ModulePreviewPage extends ConsumerWidget {
  const ModulePreviewPage({required this.module, super.key});

  final DebugTuningModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(debugTuningControllerProvider);
    final theme = Theme.of(context);
    final items = switch (module) {
      DebugTuningModule.connection => [
        _PreviewItem("日志级别", state.logLevel, "决定调试输出的详细程度"),
        _PreviewItem("链路优先级", state.preferredLink.toUpperCase(), "当前模拟连接优先链路"),
        _PreviewItem("请求超时", "${state.requestTimeoutMs}ms", "参数写入与读取的超时窗口"),
        _PreviewItem("自动重连", state.autoReconnect ? "开启" : "关闭", "断链后的恢复策略"),
      ],
      DebugTuningModule.tuning => [
        _PreviewItem(
          "PID 灵敏度",
          "${state.pidSensitivity.toStringAsFixed(2)}x",
          "姿态修正响应强度",
        ),
        _PreviewItem(
          "滤波强度",
          state.filterStrength.toStringAsFixed(2),
          "抗抖动与延迟平衡",
        ),
        _PreviewItem("摇杆 Expo", state.stickExpo.toStringAsFixed(2), "中心区操控曲线"),
      ],
      DebugTuningModule.monitoring => [
        _PreviewItem("实时图表", state.liveCharts ? "开启" : "关闭", "监测波形显示状态"),
        _PreviewItem("刷新频率", "${state.monitorRefreshHz}Hz", "监测卡片的更新节奏"),
        _PreviewItem(
          "电压告警",
          "${state.batteryWarningVoltage.toStringAsFixed(2)}V",
          "低电压提醒阈值",
        ),
      ],
      DebugTuningModule.blackbox => [
        _PreviewItem("采样频率", "${state.blackboxSampleRateHz}Hz", "黑匣子记录采样速率"),
        _PreviewItem("调试叠层", state.blackboxOverlay ? "开启" : "关闭", "关键事件辅助标记"),
      ],
      DebugTuningModule.map => [
        _PreviewItem(
          "播放倍率",
          "${state.mapPlaybackSpeed.toStringAsFixed(1)}x",
          "轨迹回放速度",
        ),
        _PreviewItem("尾迹长度", "${state.mapTrailSeconds}s", "地图历史轨迹保留时长"),
        _PreviewItem("自动居中", state.mapAutoCenter ? "开启" : "关闭", "播放时地图跟随策略"),
      ],
      DebugTuningModule.firmware => [
        _PreviewItem("安全刷写", state.firmwareSafeMode ? "开启" : "关闭", "升级过程保护模式"),
        _PreviewItem("分包大小", "${state.firmwareChunkSize}B", "单次传输分包大小"),
        _PreviewItem(
          "刷写后校验",
          state.verifyAfterFlash ? "开启" : "关闭",
          "升级完成后的校验策略",
        ),
      ],
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("${module.title}预览", style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(module.subtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("实时生效状态", style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text("在“调参”页修改参数后，这里的展示会立即刷新，无需重启应用。"),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                title: Text("${item.label}: ${item.value}"),
                subtitle: Text(item.description),
                leading: const Icon(Icons.tune),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewItem {
  const _PreviewItem(this.label, this.value, this.description);

  final String label;
  final String value;
  final String description;
}
