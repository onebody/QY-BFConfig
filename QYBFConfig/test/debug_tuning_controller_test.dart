import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:qybfconfig/src/features/tuning/debug_tuning_controller.dart";

void main() {
  test("controller updates values and records logs", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(debugTuningControllerProvider.notifier);

    controller.setAutoReconnect(false);
    controller.setMapAutoCenter(false);

    final state = container.read(debugTuningControllerProvider);
    expect(state.autoReconnect, isFalse);
    expect(state.mapAutoCenter, isFalse);
    expect(state.changeLog, hasLength(2));
    expect(state.changeLog.first.parameter, "自动居中");
    expect(state.changeLog.last.parameter, "自动重连");
  });

  test("resetAll restores defaults and keeps an audit entry", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(debugTuningControllerProvider.notifier);

    controller.setFirmwareSafeMode(false);
    controller.resetAll();

    final state = container.read(debugTuningControllerProvider);
    expect(state.firmwareSafeMode, isTrue);
    expect(state.changeLog.first.parameter, "全部参数");
    expect(state.changeLog.first.newValue, "默认值");
  });
}
