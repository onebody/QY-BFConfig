import "package:flutter/material.dart";

import "../connection/connection_page.dart";
import "../tuning/debug_tuning_controller.dart";
import "../tuning/tuning_page.dart";
import "module_preview_page.dart";

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _index = 0;

  static const _items = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.usb), label: "连接"),
    NavigationDestination(icon: Icon(Icons.tune), label: "调参"),
    NavigationDestination(icon: Icon(Icons.monitor_heart), label: "监测"),
    NavigationDestination(icon: Icon(Icons.query_stats), label: "黑匣子"),
    NavigationDestination(icon: Icon(Icons.map), label: "地图"),
    NavigationDestination(icon: Icon(Icons.system_update_alt), label: "固件"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: _items,
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_index) {
      0 => const ConnectionPage(),
      1 => const TuningPage(),
      2 => const ModulePreviewPage(module: DebugTuningModule.monitoring),
      3 => const ModulePreviewPage(module: DebugTuningModule.blackbox),
      4 => const ModulePreviewPage(module: DebugTuningModule.map),
      5 => const ModulePreviewPage(module: DebugTuningModule.firmware),
      _ => const _PlaceholderPage(title: "未知"),
    };
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}
