import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:qybfconfig/src/app/qybf_app.dart";

void main() {
  testWidgets("app boots and shows home tabs", (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: QYBFApp()));
    await tester.pump();
    expect(find.text("连接"), findsWidgets);
  });
}
