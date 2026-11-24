import "dart:convert";

import "package:flutter/services.dart";

final class AppConfig {
  AppConfig({
    required this.logLevel,
    required this.preferredLinkOrder,
    required this.requestTimeout,
  });

  final String logLevel;
  final List<String> preferredLinkOrder;
  final Duration requestTimeout;

  static Future<AppConfig> loadExample() async {
    final raw = await rootBundle.loadString("config/app_config.example.json");
    final map = jsonDecode(raw) as Map<String, dynamic>;

    final order = (map["preferredLinkOrder"] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);

    final timeoutMs = (map["requestTimeoutMs"] as num?)?.toInt() ?? 2000;

    return AppConfig(
      logLevel: (map["logLevel"] as String?) ?? "info",
      preferredLinkOrder: order,
      requestTimeout: Duration(milliseconds: timeoutMs),
    );
  }
}

