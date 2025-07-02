import 'package:flutter/material.dart';

// --- App Settings ---
class AppSettings {
  bool isDarkMode;
  TimeOfDay reminderTime;
  bool remindersEnabled;
  int dailyTaskCount;
  bool isIntervalMode;
  int intervalHours;
  String selectedFont;

  AppSettings({
    this.isDarkMode = true,
    TimeOfDay? reminderTime,
    this.remindersEnabled = false,
    this.dailyTaskCount = 3,
    this.isIntervalMode = false,
    this.intervalHours = 2,
    this.selectedFont = 'Nrt Regular',
  }) : reminderTime = reminderTime ?? const TimeOfDay(hour: 20, minute: 0);

  Map<String, dynamic> toJson() => {
        'isDarkMode': isDarkMode,
        'reminderHour': reminderTime.hour,
        'reminderMinute': reminderTime.minute,
        'remindersEnabled': remindersEnabled,
        'dailyTaskCount': dailyTaskCount,
        'isIntervalMode': isIntervalMode,
        'intervalHours': intervalHours,
        'selectedFont': selectedFont,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        isDarkMode: json['isDarkMode'] ?? true,
        reminderTime: TimeOfDay(
          hour: json['reminderHour'] ?? 20,
          minute: json['reminderMinute'] ?? 0,
        ),
        remindersEnabled: json['remindersEnabled'] ?? false,
        dailyTaskCount: json['dailyTaskCount'] ?? 3,
        isIntervalMode: json['isIntervalMode'] ?? false,
        intervalHours: json['intervalHours'] ?? 2,
        selectedFont: json['selectedFont'] ?? 'Nrt Regular',
      );
}