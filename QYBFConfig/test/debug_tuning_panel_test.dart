import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:qybfconfig/src/app/qybf_app.dart";

void main() {
  testWidgets("tuning workspace supports module and mode switching", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: QYBFApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text("调参").last);
    await tester.pumpAndSettle();

    expect(find.text("专业调参工作台"), findsOneWidget);

    await tester.tap(find.byKey(const Key("module-connection")).first);
    await tester.pumpAndSettle();
    expect(find.text("连接链路 · 当前工作区"), findsOneWidget);
    expect(find.text("当前模块共 4 项核心参数，采用高级调参与实时反馈布局。"), findsOneWidget);

    await tester.tap(find.text("精简").last);
    await tester.pumpAndSettle();
    expect(find.text("精简模式规划中"), findsOneWidget);

    await tester.tap(find.text("高级").last);
    await tester.pumpAndSettle();
    expect(find.text("连接链路 · 当前工作区"), findsOneWidget);
    expect(find.byKey(const Key("resetAllButton")), findsOneWidget);
  });
}
