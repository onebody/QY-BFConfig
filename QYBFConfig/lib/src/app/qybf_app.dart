import "package:flutter/material.dart";

import "../features/home/home_page.dart";

class QYBFApp extends StatelessWidget {
  const QYBFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "QYBFConfig",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

