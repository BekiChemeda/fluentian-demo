import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsEvent {
  const AnalyticsEvent({
    required this.name,
    required this.timestamp,
    required this.properties,
  });

  final String name;
  final DateTime timestamp;
  final Map<String, dynamic> properties;

  Map<String, dynamic> toJson() => {
        'name': name,
        'timestamp': timestamp.toIso8601String(),
        'properties': properties,
      };
}

class AnalyticsService {
  static const _key = 'analytics_events_v1';
  static const _maxEvents = 200;

  Future<void> logEvent(String name, {Map<String, dynamic> properties = const {}}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];

    final event = AnalyticsEvent(
      name: name,
      timestamp: DateTime.now().toUtc(),
      properties: properties,
    );

    raw.add(jsonEncode(event.toJson()));
    if (raw.length > _maxEvents) {
      raw.removeRange(0, raw.length - _maxEvents);
    }

    await prefs.setStringList(_key, raw);
  }
}
