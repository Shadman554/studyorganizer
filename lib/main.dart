import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/ai_tools_page.dart';
import 'pages/about_me_page.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'pages/study_guide_page.dart';

import 'services/study_guide_service.dart';
import 'models/study_guide_model.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

import 'pages/study_timer_page.dart';
import 'pages/study_calendar_page.dart';
import 'pages/flashcards_page.dart';
import 'package:intl/intl.dart';
import 'services/ai_service.dart';
import 'pages/exam_page.dart';

// --- Global Variables ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
// Instead of hardcoding the timezone, we'll get it from the device
String? timeZoneName; // Will be initialized in main()

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

// --- Widget Updates ---
Future<void> updateHomeScreenWidget(Uri? uri) async {
  // ... (Keep existing updateHomeScreenWidget code)
  try {
    final prefs = await SharedPreferences.getInstance();
    final lecturesJson = prefs.getString('lectures');
    if (lecturesJson != null) {
      final List<dynamic> decoded = jsonDecode(lecturesJson);
      final lectures = decoded.map((item) => Lecture.fromJson(item)).toList();

      int totalTheory = 0, completedTheory = 0;
      int totalPractical = 0, completedPractical = 0;

      for (var lecture in lectures) {
        totalTheory += lecture.theoryLectures.length;
        completedTheory +=
            lecture.theoryLectures.where((l) => l.isCompleted).length;
        totalPractical += lecture.practicalLectures.length;
        completedPractical +=
            lecture.practicalLectures.where((l) => l.isCompleted).length;
      }

      double theoryPercentage =
          totalTheory == 0 ? 0 : (completedTheory / totalTheory) * 100;
      double practicalPercentage =
          totalPractical == 0 ? 0 : (completedPractical / totalPractical) * 100;
      double totalProgress = (totalTheory + totalPractical) == 0
          ? 0
          : ((completedTheory + completedPractical) /
                  (totalTheory + totalPractical)) *
              100;

      await HomeWidget.saveWidgetData(
          'theory_percentage', theoryPercentage.round());
      await HomeWidget.saveWidgetData(
          'practical_percentage', practicalPercentage.round());
      await HomeWidget.saveWidgetData('total_progress', totalProgress.round());
      await HomeWidget.updateWidget(
          name: 'StudyWidgetProvider', androidName: 'StudyWidgetProvider');
    }
  } catch (e) {
    print('Error updating widget: $e');
  }
}

Future<void> updateWidgets(Uri? uri) async {
  // ... (Keep existing updateWidgets code)
  print('Starting updateWidgets function...');
  try {
    final prefs = await SharedPreferences.getInstance();
    final lecturesJson = prefs.getString('lectures');
    final settingsJson = prefs.getString('settings');

    if (lecturesJson != null) {
      final List<dynamic> decoded = jsonDecode(lecturesJson);
      final lectures = decoded.map((item) => Lecture.fromJson(item)).toList();
      final settings = settingsJson != null
          ? AppSettings.fromJson(jsonDecode(settingsJson))
          : AppSettings();

      List<Map<String, dynamic>> incompleteTasks = [];
      for (var lecture in lectures) {
        incompleteTasks.addAll(lecture.theoryLectures
            .where((l) => !l.isCompleted)
            .map((l) =>
                {'name': l.name, 'type': 'Theory', 'subject': lecture.name}));
        incompleteTasks.addAll(lecture.practicalLectures
            .where((l) => !l.isCompleted)
            .map((l) => {
                  'name': l.name,
                  'type': 'Practical',
                  'subject': lecture.name
                }));
      }

      print('Total incomplete tasks found: ${incompleteTasks.length}');

      if (incompleteTasks.isEmpty) {
        await HomeWidget.saveWidgetData('daily_tasks', '[]');
      } else {
        final today = DateTime.now();
        final seed = today.year * 10000 + today.month * 100 + today.day;
        final rng = Random(seed);
        incompleteTasks.shuffle(rng);
        final taskCount = min(settings.dailyTaskCount, incompleteTasks.length);
        final selectedTasks = incompleteTasks.take(taskCount).toList();
        final tasksJson = jsonEncode(selectedTasks);
        await HomeWidget.saveWidgetData('daily_tasks', tasksJson);
        print('Selected $taskCount tasks. Saving: $tasksJson');
      }

      await HomeWidget.updateWidget(
          name: 'DailyTasksWidgetProvider',
          androidName: 'DailyTasksWidgetProvider');
      print('Daily Tasks Widget update completed');
    }
  } catch (e, stackTrace) {
    print('Error updating widgets: $e');
    print('Stack trace: $stackTrace');
  }
}

// --- Notification Functions ---

Future<void> scheduleEventNotification(StudyEvent event) async {
  print(
      'Attempting to schedule notification for event ID: ${event.id}, Title: "${event.title}" at ${event.date}');
  try {
    if (event.isCompleted) {
      print(
          'Event "${event.title}" (ID: ${event.id}) is completed. Cancelling any pending notification.');
      await flutterLocalNotificationsPlugin.cancel(event.id.hashCode);
      return;
    }

    final hasPermission = await _checkNotificationPermissions();
    if (!hasPermission) {
      print(
          'Insufficient permissions to schedule notification for event: ${event.title}');
      return;
    }

    // Check for exact alarm permission on Android 12+ (API 31+)
    if (Platform.isAndroid) {
      final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
      if (!exactAlarmStatus.isGranted) {
        print('SCHEDULE_EXACT_ALARM permission not granted. Requesting...');
        final status = await Permission.scheduleExactAlarm.request();
        if (!status.isGranted) {
          print('Warning: SCHEDULE_EXACT_ALARM permission not granted. Notifications may not be exact on Android 12+');
        }
      }
    }

    final location = tz.getLocation(timeZoneName ?? 'UTC');
    final now = tz.TZDateTime.now(location);

    // The event.date now contains the user-specified date and time
    final scheduledTZ = tz.TZDateTime.from(event.date, location);

    // Only schedule if the calculated notification time is in the future.
    if (scheduledTZ.isBefore(now)) {
      print(
          'Skipping notification for "${event.title}" as scheduled time $scheduledTZ is in the past (Now: $now).');
      return;
    }

    // Calculate notification time (30 minutes before event if possible)
    var notificationTime = scheduledTZ.subtract(const Duration(minutes: 30));
    // If that would be in the past, use 1 minute from now
    if (notificationTime.isBefore(now)) {
      notificationTime = now.add(const Duration(minutes: 1));
    }

    // Enhanced Android notification details for better background delivery
    final androidDetails = AndroidNotificationDetails(
      'study_events_channel',
      'Study Event Reminders',
      channelDescription:
          'Reminders for scheduled study assignments, exams, etc.',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/launcher_icon',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      styleInformation: BigTextStyleInformation(''),
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      showWhen: true,
      autoCancel: true,
      channelShowBadge: true,
      fullScreenIntent: true,
      // Add these for better background delivery
      ongoing: false,
      actions: [
        AndroidNotificationAction(
          'view_event',
          'View Event',
          showsUserInterface: true,
        ),
      ],
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    // Using getEventTypeText (now defined in main.dart or imported)
    final eventTypeText = getEventTypeText(event.type);
    final notificationTitle = '$eventTypeText: ${event.title}';
    String notificationBody;
    if (event.date.hour == 0 && event.date.minute == 0) {
      // Consider it an all-day event if time is midnight
      notificationBody = 'Today: ${event.description ?? "Don't forget!"}';
    } else {
      notificationBody =
          'Starts at ${DateFormat.jm().format(event.date)}. ${event.description ?? ""}';
    }

    final notificationId = event.id.hashCode;

    // Cancel any existing notification first
    await flutterLocalNotificationsPlugin.cancel(notificationId);
    print(
        'Cancelled any existing notification with ID: $notificationId for "${event.title}".');

    // Schedule the notification with payload for better handling
    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      notificationTitle,
      notificationBody,
      notificationTime, // Using notification time (30 min before event or 1 min from now)
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Changed for better background delivery
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'event_id': event.id,
        'event_title': event.title,
        'event_type': event.type.index,
      }),
    );

    print(
        'Successfully scheduled notification (ID: $notificationId) for: "${event.title}" at $notificationTime');
  } catch (e, stackTrace) {
    print('Error in scheduleEventNotification for "${event.title}": $e');
    print('Stack trace: $stackTrace');
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle actions when the app is in the background or terminated
  print(
      'Notification Tapped Background: Payload: ${notificationResponse.payload}, ID: ${notificationResponse.id}');
  // Add any logic needed when a notification is tapped from background/terminated state.
  // e.g., saving the payload to SharedPreferences to be read when the app opens.
}

Future<void> _initializeNotifications() async {
  print('Initializing notifications system...');
  try {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    bool? initialized = await flutterLocalNotificationsPlugin
        .initialize(initializationSettings, onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) async {
      print(
          'Notification tapped (foreground): Payload: ${notificationResponse.payload}, ID: ${notificationResponse.id}, ActionID: ${notificationResponse.actionId}');
    }, onDidReceiveBackgroundNotificationResponse: notificationTapBackground);
    print('FlutterLocalNotificationsPlugin initialized: $initialized');

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Channel for Calendar Study Events
      const AndroidNotificationChannel studyEventsChannel =
          AndroidNotificationChannel(
        'study_events_channel', // For calendar events
        'Study Event Reminders',
        description:
            'Channel for study-related event reminders like exams, assignments.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      await androidPlugin.createNotificationChannel(studyEventsChannel);
      print(
          'Notification channel "study_events_channel" created/updated successfully.');

      // --- ADD THIS CHANNEL for Lecture Reminders ---
      const AndroidNotificationChannel lectureRemindersChannel =
          AndroidNotificationChannel(
        'study_reminders', // For general lecture study reminders
        'Lecture Study Reminders',
        description:
            'Reminders for completing study lectures based on settings.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      await androidPlugin.createNotificationChannel(lectureRemindersChannel);
      print(
          'Notification channel "study_reminders" created/updated successfully.');
      // --- END ADDED CHANNEL ---
    }
  } catch (e, stackTrace) {
    print('Error initializing notifications system: $e\n$stackTrace');
  }
}

Future<bool> _checkNotificationPermissions() async {
  print("Checking notification permissions...");
  if (Platform.isAndroid) {
    // 1. Basic Notification Permission (POST_NOTIFICATIONS for Android 13+)
    var notificationStatus = await Permission.notification.status;
    print("Initial Notification Permission status: $notificationStatus");
    if (notificationStatus.isDenied) {
      print('Notification permission is denied, requesting...');
      notificationStatus = await Permission.notification.request();
      print(
          'Notification permission status after request: $notificationStatus');
    }
    if (!notificationStatus.isGranted) {
      print(
          '🔴 Notification permission was NOT granted. Basic notifications will fail.');
      return false; // Essential permission
    }
    print('✅ Notification permission is granted.');

    // 2. Exact Alarm Permission (SCHEDULE_EXACT_ALARM for Android 12+)
    // Critical for timely, precise notifications on Android 12+
    // On Android 14+, this often needs to be granted manually by the user in system settings.
    var exactAlarmStatus = await Permission.scheduleExactAlarm.status;
    print('Initial SCHEDULE_EXACT_ALARM status: $exactAlarmStatus');

    if (!exactAlarmStatus.isGranted) {
      // More direct check if not granted
      print(
          'SCHEDULE_EXACT_ALARM permission not granted. Requesting (may not show dialog on Android 14+ if previously denied/restricted)...');
      exactAlarmStatus = await Permission.scheduleExactAlarm.request();
      print('SCHEDULE_EXACT_ALARM status after request: $exactAlarmStatus');

      if (!exactAlarmStatus.isGranted) {
        print(
            '🟡 SCHEDULE_EXACT_ALARM permission was NOT granted. Notifications may be inexact, delayed, or fail on some Android versions (especially 14+). User may need to grant manually via App Settings > Permissions > Alarms & Reminders.');
        // For critical timing, you might want to return false or strongly guide the user.
        // For now, we allow proceeding, but with a warning.
      } else {
        print('✅ SCHEDULE_EXACT_ALARM permission is granted.');
      }
    } else {
      print('✅ SCHEDULE_EXACT_ALARM permission is already granted.');
    }

    // 3. Check for battery optimization exemption - critical for reliable notifications
    bool isBatteryOptimizationExempt = false;
    try {
      isBatteryOptimizationExempt = await Permission.ignoreBatteryOptimizations.isGranted;
      print('Battery optimization exemption status: $isBatteryOptimizationExempt');

      if (!isBatteryOptimizationExempt) {
        print('Requesting battery optimization exemption...');
        await Permission.ignoreBatteryOptimizations.request();
        isBatteryOptimizationExempt = await Permission.ignoreBatteryOptimizations.isGranted;
        print('Battery optimization exemption after request: $isBatteryOptimizationExempt');
      }
    } catch (e) {
      print('Error checking battery optimization: $e');
    }

    // Return true if at least basic notification permission is granted.
    // The exactness of alarms will depend on SCHEDULE_EXACT_ALARM.
    return true;
  }
  return true; // For non-Android platforms or if permissions are already fine.
}

// Keep scheduleReminderNotification as is, or refactor if needed
Future<void> scheduleReminderNotification(
    AppSettings settings, List<Lecture> lectures, bool remindersEnabled) async {
  print('Scheduling reminder notification with settings: ${settings.reminderTime.hour}:${settings.reminderTime.minute}');

  try {
    // Cancel any existing reminders first
    await flutterLocalNotificationsPlugin.cancelAll();

    // If reminders are disabled, just exit after canceling
    if (!remindersEnabled || !settings.remindersEnabled) {
      print('Reminders are disabled. Not scheduling any notifications.');
      return;
    }

    // Check permissions
    final hasPermission = await _checkNotificationPermissions();
    if (!hasPermission) {
      print('Insufficient permissions to schedule reminder notifications');
      return;
    }

    // Get the timezone location
    final location = tz.getLocation(timeZoneName ?? 'UTC');

    // Calculate when to show the notification
    final now = tz.TZDateTime.now(location);
    var scheduledDate = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      settings.reminderTime.hour,
      settings.reminderTime.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    print('Scheduling notification for: $scheduledDate');

    // Count incomplete lectures for notification content
    int incompleteCount = 0;
    for (var lecture in lectures) {
      incompleteCount += lecture.theoryLectures.where((l) => !l.isCompleted).length;
      incompleteCount += lecture.practicalLectures.where((l) => !l.isCompleted).length;
    }

    // Create the notification details
    const androidDetails = AndroidNotificationDetails(
      'study_reminders',
      'Lecture Study Reminders',
      channelDescription: 'Reminders for completing study lectures based on settings.',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/launcher_icon',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      showWhen: true,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    // Schedule the notification
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, // ID for the daily reminder
      'Time to Study!',
      incompleteCount > 0
          ? 'You have $incompleteCount incomplete lectures to review.'
          : 'Great job! All your lectures are complete.',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.alarmClock, // Changed to alarmClock for better reliability on Android 15
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Daily at the same time
      payload: 'daily_reminder',
    );

    print('Successfully scheduled notification for ${settings.reminderTime.hour}:${settings.reminderTime.minute}');
  } catch (e, stackTrace) {
    print('Error scheduling reminder notification: $e');
    print('Stack trace: $stackTrace');
  }
}

// --- Event Type Enum ---
enum EventType {
  quiz,
  assignment,
  report,
  exam,
  study,
  project,
  presentation,
  meeting,
  other
}

// --- Study Event Model ---
class StudyEvent {
  String id;
  String title;
  String? description;
  DateTime date; // Will store both date AND time
  EventType type;
  bool isCompleted;

  StudyEvent({
    String? id,
    required this.title,
    this.description,
    required this.date,
    required this.type,
    this.isCompleted = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'type': type.toString(),
        'isCompleted': isCompleted,
      };

  factory StudyEvent.fromJson(Map<String, dynamic> json) => StudyEvent(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        date: DateTime.parse(json['date']),
        type: EventType.values.firstWhere(
          (e) => e.toString() == json['type'],
          orElse: () => EventType.other,
        ),
        isCompleted: json['isCompleted'] ?? false,
      );
}

// --- Event Helper Functions (now in main.dart) ---
String getEventTypeText(EventType type) {
  switch (type) {
    case EventType.quiz:
      return 'Quiz';
    case EventType.assignment:
      return 'Assignment';
    case EventType.report:
      return 'Report';
    case EventType.exam:
      return 'Exam';
    case EventType.study:
      return 'Study Session';
    case EventType.project:
      return 'Project Deadline';
    case EventType.presentation:
      return 'Presentation';
    case EventType.meeting:
      return 'Meeting';
    case EventType.other:
      return 'Other Event';
  }
}

IconData getEventTypeIcon(EventType type) {
  switch (type) {
    case EventType.quiz:
      return Icons.quiz_outlined;
    case EventType.assignment:
      return Icons.assignment_turned_in_outlined;
    case EventType.report:
      return Icons.article_outlined;
    case EventType.exam:
      return Icons.school_outlined;
    case EventType.study:
      return Icons.book_outlined;
    case EventType.project:
      return Icons.construction_outlined;
    case EventType.presentation:
      return Icons.slideshow_outlined;
    case EventType.meeting:
      return Icons.people_alt_outlined;
    case EventType.other:
      return Icons.event_note_outlined;
  }
}

Color getEventTypeColor(EventType type, BuildContext context) {
  // Using theme colors for better adaptability
  final theme = Theme.of(context);
  switch (type) {
    case EventType.quiz:
      return Colors.orangeAccent[700] ?? Colors.orange;
    case EventType.assignment:
      return theme.colorScheme.primary;
    case EventType.report:
      return Colors.green[600] ?? Colors.green;
    case EventType.exam:
      return theme.colorScheme.error;
    case EventType.study:
      return Colors.purpleAccent[400] ?? Colors.purple;
    case EventType.project:
      return Colors.teal[600] ?? Colors.teal;
    case EventType.presentation:
      return Colors.amber[700] ?? Colors.amber;
    case EventType.meeting:
      return Colors.indigoAccent[400] ?? Colors.indigo;
    case EventType.other:
      return Colors.grey[600] ?? Colors.grey;
  }
}

// Keep _requestNotificationPermissions as is
Future<bool> _requestNotificationPermissions() async {
  // ... (Keep existing _requestNotificationPermissions code)
  if (Platform.isAndroid) {
    if (await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }
  return true;
}

// Updated test notification function
Future<void> sendTestNotification() async {
  print('Sending test notification...');
  const androidDetails = AndroidNotificationDetails(
    'test_channel',
    'Test Notifications',
    channelDescription: 'Channel for testing notifications',
    importance: Importance.max,
    priority: Priority.high,
    enableVibration: true,
    playSound: true,
    category: AndroidNotificationCategory.alarm,
    fullScreenIntent: true,
  );

  const platformDetails = NotificationDetails(android: androidDetails);

  try {
    await flutterLocalNotificationsPlugin.show(
      999, // Unique ID for test notification
      'Test Notification',
      'This is a test notification from Study Organizer',
      platformDetails,
    );
    print('Test notification sent successfully');
  } catch (e) {
    print('Error sending test notification: $e');
  }
}

// --- Main App Setup ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  // Set preferred frame rate to 120 FPS - only after Flutter is initialized
  if (Platform.isAndroid) {
    try {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      // Try to set high refresh rate, but don't crash if it fails
      try {
        await FlutterDisplayMode.setHighRefreshRate();
      } catch (e) {
        print('Could not set high refresh rate: $e');
      }
    } catch (e) {
      print('Error setting device orientation: $e');
    }
  }

  // Get device timezone using timezone package
  try {
    // Get the local timezone from the system
    // Since we can't directly get it without flutter_timezone, we'll use the current time offset
    final DateTime now = DateTime.now();
    final Duration offset = now.timeZoneOffset;
    final int offsetHours = offset.inHours;
    final int offsetMinutes = (offset.inMinutes % 60).abs();
    final String sign = offset.isNegative ? '-' : '+';

    // Format as UTC+X or UTC-X
    final String formattedOffset = 'UTC$sign${offsetHours.abs().toString().padLeft(2, '0')}:${offsetMinutes.toString().padLeft(2, '0')}';
    print('Device timezone offset: $formattedOffset');

    // Try to find a timezone with this offset
    final availableTimezones = tz.timeZoneDatabase.locations.keys.toList();
    bool found = false;

    // First try to find a timezone with the exact same offset
    for (final tzName in availableTimezones) {
      final location = tz.getLocation(tzName);
      final nowInTz = tz.TZDateTime.now(location);
      if (nowInTz.timeZoneOffset == offset) {
        timeZoneName = tzName;
        found = true;
        print('Found matching timezone: $timeZoneName');
        break;
      }
    }

    // If no exact match, use UTC
    if (!found) {
      timeZoneName = 'UTC'; // Fallback to UTC if we can't determine the timezone
      print('No matching timezone found, using UTC');
    }
  } catch (e) {
    print('Error determining timezone: $e');
    timeZoneName = 'UTC'; // Fallback to UTC if we can't determine the timezone
  }

  final location = tz.getLocation(timeZoneName ?? 'UTC');
  tz.setLocalLocation(location); // Set default timezone for the app

  // Initialize notifications first
  await _initializeNotifications();

  // Request permissions after basic initialization
  print("Requesting initial set of permissions in main()...");
  if (Platform.isAndroid) {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage, // Required for accessing PDF files
      Permission.notification,
      Permission.scheduleExactAlarm, // Crucial for precise reminders
    ].request();
    statuses.forEach((permission, status) {
      print('$permission status: $status');
    });

    // For Android 11+ (API level 30+), we might need to request additional permissions
    try {
      // Check if we need to request manage external storage permission
      // This permission is only needed on Android 11+ (API 30+)
      var manageStatus = await Permission.manageExternalStorage.status;
      print('Permission.manageExternalStorage initial status: $manageStatus');

      if (manageStatus.isDenied) {
        manageStatus = await Permission.manageExternalStorage.request();
        print('Permission.manageExternalStorage status after request: $manageStatus');
      }
    } catch (e) {
      print('Error requesting manageExternalStorage permission: $e');
    }
  }

  await HomeWidget.registerBackgroundCallback(
      updateWidgets); // For your home screen widgets
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatefulWidget {
  final SharedPreferences prefs;
  const MyApp({super.key, required this.prefs});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppSettings settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settingsJson = widget.prefs.getString('settings');
    if (settingsJson != null) {
      setState(() {
        settings = AppSettings.fromJson(jsonDecode(settingsJson));
      });
    }
  }

  void updateSettings(AppSettings newSettings) {
    setState(() {
      settings = newSettings;
    });
    widget.prefs.setString('settings', jsonEncode(settings.toJson()));
  }

  // Helper method to get the font family based on selection
  String _getFontFamily() {
    switch (settings.selectedFont) {
      case 'Nrt Bold':
        return 'Nrt_bold';
      case 'Nrt Regular':
        return 'Nrt_regular';
      case 'K24':
        return 'K24';
      case 'Speda':
        return 'Speda';
      default:
        return ''; // Default system font
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the selected font family
    final String fontFamily = _getFontFamily();

    // Create text theme with the selected font
    final TextTheme darkTextTheme = fontFamily.isEmpty
        ? ThemeData.dark().textTheme
        : ThemeData.dark().textTheme.apply(fontFamily: fontFamily);

    final TextTheme lightTextTheme = fontFamily.isEmpty
        ? ThemeData.light().textTheme
        : ThemeData.light().textTheme.apply(fontFamily: fontFamily);

    return MaterialApp(
      title: 'Wanakanm',
      theme: settings.isDarkMode
          ? ThemeData.dark(useMaterial3: true).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Colors.teal,
                secondary: Colors.tealAccent,
                surface: Color(0xFF1F1F1F),
                background: Color(0xFF121212),
                onPrimary: Colors.white,
                onSecondary: Colors.black,
                surfaceVariant: Color(0xFF3A3A3A),
              ),
              textTheme: darkTextTheme,
              scaffoldBackgroundColor: const Color(0xFF121212),
              appBarTheme: AppBarTheme(
                backgroundColor: const Color(0xFF1F1F1F),
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                titleTextStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    fontFamily: fontFamily.isEmpty ? null : fontFamily,
                    color: Colors.white),
              ),
              drawerTheme: const DrawerThemeData(
                backgroundColor: Color(0xFF1F1F1F),
              ),
              cardTheme: CardTheme(
                color: const Color(0xFF2A2A2A),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              progressIndicatorTheme:
                  const ProgressIndicatorThemeData(color: Colors.teal),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                  backgroundColor: Colors.teal, foregroundColor: Colors.white),
              listTileTheme: ListTileThemeData(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                iconColor: Colors.tealAccent[100],
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                prefixIconColor: Colors.tealAccent[100],
              ),
              useMaterial3: true,
            )
          : ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: Colors.blue,
                secondary: Colors.blueAccent,
                surface: Colors.white,
                background: Color(0xFFF0F2F5),
                surfaceVariant: Color(0xFFE0E0E0),
              ),
              textTheme: lightTextTheme,
              scaffoldBackgroundColor: const Color(0xFFF0F2F5),
              appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                  titleTextStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
              cardTheme: CardTheme(
                  color: Colors.white,
                  elevation: 2,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0))),
              progressIndicatorTheme:
                  const ProgressIndicatorThemeData(color: Colors.blue),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                  backgroundColor: Colors.blue, foregroundColor: Colors.white),
              listTileTheme: ListTileThemeData(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                  iconColor: Colors.blue[600]),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!)),
                filled: true,
                fillColor: Colors.white,
                prefixIconColor: Colors.blue[600],
              ),
              useMaterial3: true,
            ),
      home: HomePage(
        prefs: widget.prefs,
        settings: settings,
        onSettingsChanged: updateSettings,
      ),
    );
  }
}

// --- Placeholder/Model Classes & Pages ---
// Enum for identifying pages/drawer items
enum AppPage {
  home,
  dashboard,
  studyTimer,
  studyCalendar,
  flashcards,
  backupRestore, // For the ExpansionTile itself, if needed, or handle sub-items separately
  settings,
  aboutMe,
}

// Keep Lecture, PDFLecture classes as they are.
// Keep HomePage, AddLecturePage, LectureDetailPage, SettingsPage, AnalysisPage as they are.
// ... (Your existing code for these classes)
class PDFLecture {
  String id;
  String name;
  String? pdfPath;
  DateTime dateAdded;
  bool isCompleted;

  PDFLecture({
    required this.name,
    this.pdfPath,
    String? id,
    DateTime? dateAdded,
    this.isCompleted = false,
  })  : id = id ?? '${DateTime.now().millisecondsSinceEpoch}_${UniqueKey()}',
        dateAdded = dateAdded ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pdfPath': pdfPath,
      'dateAdded': dateAdded.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  factory PDFLecture.fromJson(Map<String, dynamic> json) {
    return PDFLecture(
      id: json['id'],
      name: json['name'],
      pdfPath: json['pdfPath'],
      dateAdded: DateTime.parse(json['dateAdded']),
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

class Lecture {
  String id;
  String name;
  String subtitle;
  String classroom;
  List<PDFLecture> theoryLectures;
  List<PDFLecture> practicalLectures;
  DateTime dateAdded;

  Lecture({
    required this.name,
    this.subtitle = '',
    this.classroom = '',
    String? id,
    DateTime? dateAdded,
    List<PDFLecture>? theoryLectures,
    List<PDFLecture>? practicalLectures,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        dateAdded = dateAdded ?? DateTime.now(),
        theoryLectures = theoryLectures ?? [],
        practicalLectures = practicalLectures ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'classroom': classroom,
      'dateAdded': dateAdded.toIso8601String(),
      'theoryLectures': theoryLectures.map((e) => e.toJson()).toList(),
      'practicalLectures': practicalLectures.map((e) => e.toJson()).toList(),
    };
  }

  factory Lecture.fromJson(Map<String, dynamic> json) {
    return Lecture(
      id: json['id'],
      name: json['name'],
      subtitle: json['subtitle'] ?? '',
      classroom: json['classroom'] ?? '',
      dateAdded: DateTime.parse(json['dateAdded']),
      theoryLectures: (json['theoryLectures'] as List)
          .map((e) => PDFLecture.fromJson(e))
          .toList(),
      practicalLectures: (json['practicalLectures'] as List)
          .map((e) => PDFLecture.fromJson(e))
          .toList(),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final AppSettings settings;
  final Function(AppSettings) onSettingsChanged;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Local state to track dark mode setting
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    // Initialize local state from widget settings
    _isDarkMode = widget.settings.isDarkMode;
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local state when widget settings change
    if (oldWidget.settings.isDarkMode != widget.settings.isDarkMode) {
      setState(() {
        _isDarkMode = widget.settings.isDarkMode;
      });
    }
  }
  Future<void> _selectTime(BuildContext context) async {
    final ThemeData theme = Theme.of(context); // Get current theme
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.settings.reminderTime,
      builder: (context, child) {
        return Theme(
          // Apply a more specific TimePicker theme that adapts
          data: theme.copyWith(
              timePickerTheme: TimePickerThemeData(
                backgroundColor: theme.dialogTheme.backgroundColor ??
                    theme.colorScheme.surface,
                hourMinuteTextColor: MaterialStateColor.resolveWith((states) =>
                    states.contains(MaterialState.selected)
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface),
                hourMinuteColor: MaterialStateColor.resolveWith((states) =>
                    states.contains(MaterialState.selected)
                        ? theme.colorScheme.primary.withOpacity(0.8)
                        : theme.colorScheme.surfaceVariant.withOpacity(0.7)),
                dayPeriodTextColor: MaterialStateColor.resolveWith((states) =>
                    states.contains(MaterialState.selected)
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant),
                dayPeriodColor: MaterialStateColor.resolveWith((states) =>
                    states.contains(MaterialState.selected)
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceVariant.withOpacity(0.5)),
                dayPeriodBorderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.5)),
                dialHandColor: theme.colorScheme.primary,
                dialBackgroundColor:
                    theme.colorScheme.surfaceVariant.withOpacity(0.3),
                dialTextColor: MaterialStateColor.resolveWith((states) =>
                    states.contains(MaterialState.selected)
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant),
                entryModeIconColor: theme.colorScheme.primary,
                helpTextStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7)),
              ),
              textButtonTheme: TextButtonThemeData(
                  // Style buttons in TimePicker
                  style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary))),
          child: child!,
        );
      },
    );
    if (picked != null && picked != widget.settings.reminderTime) {
      widget.onSettingsChanged(AppSettings(
        // ... (rest of your AppSettings constructor)
        isDarkMode: widget.settings.isDarkMode,
        reminderTime: picked,
        remindersEnabled: widget.settings.remindersEnabled,
        dailyTaskCount: widget.settings.dailyTaskCount,
        isIntervalMode: widget.settings.isIntervalMode,
        intervalHours: widget.settings.intervalHours,
        selectedFont: widget.settings.selectedFont,
      ));
      // Re-schedule the reminder with the new time if reminders are enabled
      if (widget.settings.remindersEnabled) {
        _scheduleReminder(context, picked);
      }
    }
  }

  void _scheduleReminder(BuildContext context, TimeOfDay time) async {
    if (!widget.settings.remindersEnabled) return;

    try {
      // Store ScaffoldMessengerState
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // Request notification permission first
      final hasPermission = await _requestNotificationPermissions();
      if (!hasPermission) {
        if (!context.mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Notification permission is required for reminders',
              style: TextStyle(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                openAppSettings();
              },
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get lectures from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final lecturesJson = prefs.getString('lectures');
      if (lecturesJson != null) {
        final List<dynamic> decoded = jsonDecode(lecturesJson);
        final lectures = decoded.map((item) => Lecture.fromJson(item)).toList();

        // Update settings before scheduling
        final newSettings = AppSettings(
          isDarkMode: widget.settings.isDarkMode,
          reminderTime: time,
          remindersEnabled: true,
          dailyTaskCount: widget.settings.dailyTaskCount,
          isIntervalMode: widget.settings.isIntervalMode,
          intervalHours: widget.settings.intervalHours,
          selectedFont: widget.settings.selectedFont,
        );
        widget.onSettingsChanged(newSettings);

        await scheduleReminderNotification(
          newSettings,
          lectures,
          true,
        );

        if (!context.mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Daily reminder set for ${time.format(context)}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error scheduling notification: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to set reminder: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add this method to handle task count changes
  void _showTaskCountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Tasks Count'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Select how many random incomplete tasks to show in the widget each day:'),
            const SizedBox(height: 16),
            DropdownButton<int>(
              value: widget.settings.dailyTaskCount,
              items: [1, 2, 3, 4, 5].map((count) {
                return DropdownMenuItem<int>(
                  value: count,
                  child: Text('$count ${count == 1 ? 'task' : 'tasks'}'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  widget.onSettingsChanged(AppSettings(
                    isDarkMode: widget.settings.isDarkMode,
                    reminderTime: widget.settings.reminderTime,
                    remindersEnabled: widget.settings.remindersEnabled,
                    dailyTaskCount: value,
                    isIntervalMode: widget.settings.isIntervalMode,
                    intervalHours: widget.settings.intervalHours,
                    selectedFont: widget.settings.selectedFont,
                  ));
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showIntervalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Interval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select how often to show notifications:'),
            const SizedBox(height: 16),
            DropdownButton<int>(
              value: widget.settings.intervalHours,
              items: [1, 2, 3, 4, 6, 8, 12].map((hours) {
                return DropdownMenuItem<int>(
                  value: hours,
                  child: Text('Every $hours ${hours == 1 ? 'hour' : 'hours'}'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  final newSettings = AppSettings(
                    isDarkMode: widget.settings.isDarkMode,
                    reminderTime: widget.settings.reminderTime,
                    remindersEnabled: widget.settings.remindersEnabled,
                    dailyTaskCount: widget.settings.dailyTaskCount,
                    isIntervalMode: true,
                    intervalHours: value,
                    selectedFont: widget.settings.selectedFont,
                  );
                  widget.onSettingsChanged(newSettings);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Show font selection dialog
  void _showFontSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Font'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose a font for the app:'),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: widget.settings.selectedFont,
              items: [
                'Default',
                'Nrt Bold',
                'Nrt Regular',
                'K24',
                'Speda',
              ].map((font) {
                return DropdownMenuItem<String>(
                  value: font,
                  child: Text(font, style: TextStyle(
                    fontFamily: font == 'Default' ? null : 
                      font == 'Nrt Bold' ? 'Nrt_bold' :
                      font == 'Nrt Regular' ? 'Nrt_regular' :
                      font == 'K24' ? 'K24' : 'Speda',
                  )),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  final newSettings = AppSettings(
                    isDarkMode: widget.settings.isDarkMode,
                    reminderTime: widget.settings.reminderTime,
                    remindersEnabled: widget.settings.remindersEnabled,
                    dailyTaskCount: widget.settings.dailyTaskCount,
                    isIntervalMode: widget.settings.isIntervalMode,
                    intervalHours: widget.settings.intervalHours,
                    selectedFont: value,
                  );
                  widget.onSettingsChanged(newSettings);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, String title, IconData icon,
      List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

   Widget _buildInfoBox(BuildContext context, String text) {
    final theme = Theme.of(context); // Get theme
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1), // Use theme
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: theme.colorScheme.primary.withOpacity(0.3))),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: theme.colorScheme.primary, // Use theme
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  // Ensure good contrast on the slightly tinted background
                  color: theme.colorScheme.onSurface.withOpacity(0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8), // Add padding around the list
        children: [
          _buildSettingsCard(
            context,
            'Appearance',
            Icons.palette_outlined, // Add icon
            [
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Toggle dark theme'),
                value: _isDarkMode,
                onChanged: (value) {
                  // Update local state first
                  setState(() {
                    _isDarkMode = value;
                  });
                  // Then update app settings
                  widget.onSettingsChanged(AppSettings(
                    isDarkMode: value,
                    reminderTime: widget.settings.reminderTime,
                    remindersEnabled: widget.settings.remindersEnabled,
                    dailyTaskCount: widget.settings.dailyTaskCount,
                    isIntervalMode: widget.settings.isIntervalMode,
                    intervalHours: widget.settings.intervalHours,
                    selectedFont: widget.settings.selectedFont,
                  ));
                },
                secondary: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _isDarkMode
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    key: ValueKey<bool>(_isDarkMode),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 70, endIndent: 16),
              ListTile(
                leading: const SizedBox(
                  width: 56, 
                  child: Icon(Icons.font_download_outlined)
                ),
                title: const Text('App Font'),
                subtitle: Text(widget.settings.selectedFont),
                onTap: () => _showFontSelectionDialog(context),
                dense: true,
              ),
            ],
          ),
          _buildSettingsCard(
            context,
            'Reminders',
            Icons.notifications_active_outlined, // Updated icon
            [
              SwitchListTile(
                title: const Text(
                  'Enable Reminders',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  'Get notified about incomplete lectures',
                  style: TextStyle(fontSize: 13),
                ),
                value: widget.settings.remindersEnabled,
                onChanged: (value) async {
                  if (value) {
                    final hasPermission =
                        await _requestNotificationPermissions();
                    if (!hasPermission) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Notification permission is required for reminders',
                            style: TextStyle(color: Colors.white),
                          ),
                          action: SnackBarAction(
                            label: 'Settings',
                            onPressed: () {
                              openAppSettings();
                            },
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  }

                  final newSettings = AppSettings(
                    isDarkMode: widget.settings.isDarkMode,
                    reminderTime: widget.settings.reminderTime,
                    remindersEnabled: value,
                    dailyTaskCount: widget.settings.dailyTaskCount,
                    isIntervalMode: widget.settings.isIntervalMode,
                    intervalHours: widget.settings.intervalHours,
                    selectedFont: widget.settings.selectedFont,
                  );

                  widget.onSettingsChanged(newSettings);

                  if (value) {
                    if (!mounted) return;
                    _scheduleReminder(context, widget.settings.reminderTime);
                  }
                },
                secondary: Icon(
                  widget.settings.remindersEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                ),
              ),
              if (widget.settings.remindersEnabled) ...[
                const Divider(height: 1, indent: 70, endIndent: 16),
                SwitchListTile(
                  title: const Text(
                    'Notification Mode',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    widget.settings.isIntervalMode
                        ? 'Interval: Every ${widget.settings.intervalHours} hours'
                        : 'Daily at ${widget.settings.reminderTime.format(context)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: widget.settings.isIntervalMode,
                  secondary: Icon(
                    widget.settings.isIntervalMode
                        ? Icons.timer_outlined
                        : Icons.access_time_outlined,
                  ),
                  onChanged: (value) {
                    widget.onSettingsChanged(AppSettings(
                      isDarkMode: widget.settings.isDarkMode,
                      reminderTime: widget.settings.reminderTime,
                      remindersEnabled: widget.settings.remindersEnabled,
                      dailyTaskCount: widget.settings.dailyTaskCount,
                      isIntervalMode: value,
                      intervalHours: widget.settings.intervalHours,
                    ));
                  },
                ),
                if (widget.settings.isIntervalMode)
                  ListTile(
                    // leading: const SizedBox(width: 56, child: Icon(Icons.av_timer_outlined)), // Old
                    leading: SizedBox(
                        width: 56,
                        child: Icon(Icons.av_timer_outlined,
                            color:
                                Theme.of(context).colorScheme.primary)), // New
                    title: const Text('Interval Duration'),
                    subtitle:
                        Text('Every ${widget.settings.intervalHours} hours'),
                    onTap: () => _showIntervalDialog(context),
                    dense: true,
                  )
                else
                  ListTile(
                    // leading: const SizedBox(width: 56, child: Icon(Icons.more_time_outlined)), // Old
                    leading: SizedBox(
                        width: 56,
                        child: Icon(Icons.more_time_outlined,
                            color:
                                Theme.of(context).colorScheme.primary)), // New
                    title: const Text('Reminder Time'),
                    subtitle:
                        Text(widget.settings.reminderTime.format(context)),
                    onTap: () => _selectTime(context),
                    dense: true,
                  ),
                _buildInfoBox(
                  // Use a helper for info box
                  context,
                  widget.settings.isIntervalMode
                      ? 'You will be reminded every ${widget.settings.intervalHours} hours about your incomplete lectures.'
                      : 'You will be reminded daily at ${widget.settings.reminderTime.format(context)} about your incomplete lectures.',
                ),

                // Test notification button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Request notification permission first
                      final hasPermission = await _requestNotificationPermissions();
                      if (!hasPermission) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Notification permission is required for testing',
                              style: TextStyle(color: Colors.white),
                            ),
                            action: SnackBarAction(
                              label: 'Settings',
                              onPressed: () {
                                openAppSettings();
                              },
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Send test notification
                      await sendTestNotification();

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test notification sent!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Test Notification'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          _buildSettingsCard(
            context,
            'Daily Tasks Widget',
            Icons.widgets_outlined,
            [
              ListTile(
                title: const Text('Number of Daily Tasks'),
                subtitle:
                    Text('${widget.settings.dailyTaskCount} tasks per day'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTaskCountDialog(context),
                leading: const Icon(Icons.format_list_numbered_outlined),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Tasks are randomly selected from your incomplete lectures each day.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AnalysisPage extends StatelessWidget {
  final List<Lecture> lectures;

  const AnalysisPage({super.key, required this.lectures});

  // Helper to calculate progress for a single lecture
  Map<String, dynamic> _getLectureProgress(Lecture lecture) {
    int theoryTotal = lecture.theoryLectures.length;
    int theoryCompleted =
        lecture.theoryLectures.where((l) => l.isCompleted).length;
    int practicalTotal = lecture.practicalLectures.length;
    int practicalCompleted =
        lecture.practicalLectures.where((l) => l.isCompleted).length;

    int totalLectures = theoryTotal + practicalTotal;
    int completedLectures = theoryCompleted + practicalCompleted;
    double progress =
        totalLectures == 0 ? 0 : completedLectures / totalLectures;

    return {
      'name': lecture.name,
      'total': totalLectures,
      'completed': completedLectures,
      'progress': progress,
      'theoryTotal': theoryTotal,
      'theoryCompleted': theoryCompleted,
      'practicalTotal': practicalTotal,
      'practicalCompleted': practicalCompleted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    int totalOverallTheory = 0;
    int completedOverallTheory = 0;
    int totalOverallPractical = 0;
    int completedOverallPractical = 0;
    List<Map<String, dynamic>> subjectProgressList = [];
    int fullyCompletedSubjects = 0;

    for (var lecture in lectures) {
      final progressData = _getLectureProgress(lecture);
      subjectProgressList.add(progressData);

      totalOverallTheory += progressData['theoryTotal'] as int;
      completedOverallTheory += progressData['theoryCompleted'] as int;
      totalOverallPractical += progressData['practicalTotal'] as int;
      completedOverallPractical += progressData['practicalCompleted'] as int;

      if (progressData['progress'] == 1.0 && progressData['total'] > 0) {
        fullyCompletedSubjects++;
      }
    }

    int totalOverallLectures = totalOverallTheory + totalOverallPractical;
    int completedOverallLectures =
        completedOverallTheory + completedOverallPractical;
    double overallPercentage = totalOverallLectures == 0
        ? 0
        : completedOverallLectures / totalOverallLectures;

    double theoryProgressFraction = totalOverallTheory == 0
        ? 0
        : completedOverallTheory / totalOverallTheory;
    double practicalProgressFraction = totalOverallPractical == 0
        ? 0
        : completedOverallPractical / totalOverallPractical;

    subjectProgressList.sort(
        (a, b) => (b['progress'] as double).compareTo(a['progress'] as double));

    String? strongestSubject;
    if (subjectProgressList.isNotEmpty &&
        (subjectProgressList.first['progress'] as double) >= 0.8 &&
        (subjectProgressList.first['total'] as int > 0)) {
      strongestSubject = subjectProgressList.first['name'] as String;
    }

    String? weakestSubject;
    if (subjectProgressList.isNotEmpty) {
      final potentialWeakest = subjectProgressList
          .where(
              (s) => (s['progress'] as double) < 0.6 && (s['total'] as int > 0))
          .toList();
      if (potentialWeakest.isNotEmpty) {
        // Sort by progress ascending to get the actual weakest among these
        potentialWeakest.sort((a, b) =>
            (a['progress'] as double).compareTo(b['progress'] as double));
        weakestSubject = potentialWeakest.first['name'] as String;
      }
    }

    double? progressOfSubjectIfStrongestIsWeakest;
    if (strongestSubject != null &&
        strongestSubject == weakestSubject &&
        subjectProgressList.isNotEmpty) {
      var subjectData = subjectProgressList.firstWhere(
        (s) => s['name'] == weakestSubject,
        orElse: () => <String, dynamic>{},
      );
      if (subjectData.isNotEmpty && subjectData['progress'] != null) {
        progressOfSubjectIfStrongestIsWeakest =
            subjectData['progress'] as double?;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Dashboard 📊'),
      ),
      body: lectures.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined,
                      size: 80, color: theme.hintColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text("No Lecture Data",
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: theme.hintColor)),
                  const SizedBox(height: 8),
                  // --- CORRECTED PADDING ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      "Add lectures and complete PDFs to see your progress analysis.",
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.hintColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // --- END CORRECTION ---
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        _buildOverallProgress(context, overallPercentage,
                            completedOverallLectures, totalOverallLectures),
                        const SizedBox(height: 24),
                        _buildSectionTitle(context, "Category Breakdown"),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: _buildDetailedProgressCard(
                              context,
                              "Theory Focus",
                              theoryProgressFraction,
                              completedOverallTheory,
                              totalOverallTheory,
                              Icons.menu_book_outlined,
                              theme.colorScheme.primary,
                            )),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildDetailedProgressCard(
                              context,
                              "Practical Skills",
                              practicalProgressFraction,
                              completedOverallPractical,
                              totalOverallPractical,
                              Icons.science_outlined,
                              theme.colorScheme.secondary,
                            )),
                          ],
                        ),
                        if (subjectProgressList.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildSectionTitle(context, "Subject Mastery"),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
                if (subjectProgressList.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final subjectData = subjectProgressList[index];
                          return _SubjectProgressTile(
                            title: subjectData['name'] as String,
                            completed: subjectData['completed'] as int,
                            total: subjectData['total'] as int,
                            progress: subjectData['progress'] as double,
                            theme: theme,
                          );
                        },
                        childCount: subjectProgressList.length,
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        if (lectures.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildSectionTitle(context, "💡 Quick Insights"),
                          const SizedBox(height: 16),
                          // --- UPDATED CALL TO _buildInsightsCard ---
                          _buildInsightsCard(
                            context,
                            fullyCompletedSubjects,
                            lectures.length,
                            strongestSubject,
                            weakestSubject,
                            progressOfSubjectIfStrongestIsWeakest, // Pass new parameter
                          ),
                          // --- END UPDATE ---
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).hintColor.withOpacity(0.8),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
      ),
    );
  }

  Widget _buildOverallProgress(
      BuildContext context, double percentage, int completed, int total) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Overall Learning Progress",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  total > 0
                      ? "$completed of $total units covered"
                      : "No lectures yet",
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 100,
            height: 100,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: percentage),
              duration: const Duration(milliseconds: 1800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 12,
                      backgroundColor:
                          theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        "${(value * 100).toInt()}%",
                        style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedProgressCard(BuildContext context, String title,
      double percentage, int completed, int total, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "$completed / $total units",
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "${(percentage * 100).toStringAsFixed(0)}% complete",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: percentage),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutQuart,
            builder: (context, value, child) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UPDATED _buildInsightsCard SIGNATURE AND LOGIC ---
  Widget _buildInsightsCard(
      BuildContext context,
      int completedSubjects,
      int totalSubjects,
      String? strongest,
      String? weakest,
      double? progressOfSubjectIfStrongestIsWeakest) {
    final theme = Theme.of(context);
    if (totalSubjects == 0 && strongest == null && weakest == null) {
      return const SizedBox.shrink();
    }

    List<Widget> insightItems = [];

    if (totalSubjects > 0) {
      insightItems.add(_InsightItem(
          icon: completedSubjects == totalSubjects
              ? Icons.celebration_outlined
              : Icons.check_circle_outline,
          text: "$completedSubjects of $totalSubjects subjects fully mastered.",
          color: completedSubjects == totalSubjects
              ? (Colors.greenAccent[700] ?? Colors.green)
              : Colors.green,
          theme: theme));
    }

    if (strongest != null) {
      insightItems.add(_InsightItem(
          icon: Icons.emoji_events_outlined,
          text: "Stellar work in: $strongest! 🚀",
          color: theme.colorScheme.primary,
          theme: theme));
    }

    if (weakest != null && strongest != weakest) {
      insightItems.add(_InsightItem(
          icon: Icons.lightbulb_outline,
          text: "Next focus area: $weakest. You got this! 💪",
          color: Colors.orangeAccent[700] ?? Colors.orange,
          theme: theme));
    } else if (weakest != null &&
        strongest == weakest &&
        progressOfSubjectIfStrongestIsWeakest != null &&
        progressOfSubjectIfStrongestIsWeakest < 1.0) {
      insightItems.add(_InsightItem(
          icon: Icons.trending_up_outlined,
          text: "Keep pushing in: $weakest to master it! 💪",
          color: Colors.orangeAccent[700] ?? Colors.orange,
          theme: theme));
    }

    if (insightItems.isEmpty) {
      insightItems.add(_InsightItem(
          icon: Icons.info_outline,
          text: "Keep adding and completing lectures to see more insights!",
          color: theme.hintColor,
          theme: theme));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light ? Colors.white : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: insightItems,
      ),
    );
  }
  // --- END UPDATED _buildInsightsCard ---
}

class _InsightItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final ThemeData theme;

  const _InsightItem(
      {required this.icon,
      required this.text,
      required this.color,
      required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 16),
          Expanded(
              child: Text(text,
                  style: theme.textTheme.titleMedium?.copyWith(height: 1.4))),
        ],
      ),
    );
  }
}

class _SubjectProgressTile extends StatelessWidget {
  final String title;
  final int completed;
  final int total;
  final double progress;
  final ThemeData theme;

  const _SubjectProgressTile({
    required this.title,
    required this.completed,
    required this.total,
    required this.progress,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final Color progressColor =
        HSLColor.fromAHSL(1.0, 120 * progress, 0.65, 0.55).toColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light ? Colors.white : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600)),
              ),
              Text(
                "${(progress * 100).toStringAsFixed(0)}%",
                style: theme.textTheme.titleMedium?.copyWith(
                    color: progressColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            total > 0 ? "$completed of $total units completed" : "No units",
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.hintColor.withOpacity(0.8)),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutExpo,
            builder: (context, value, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor:
                      theme.colorScheme.surfaceVariant.withOpacity(0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Update HomePage to include the drawer
class HomePage extends StatefulWidget {
  final SharedPreferences prefs;
  final AppSettings settings;
  final Function(AppSettings) onSettingsChanged;

  const HomePage({
    super.key,
    required this.prefs,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Lecture> lectures = [];
  final String _lecturesKey = 'lectures';
  String _sortBy = 'name';
  bool _isDark = true;
  AppPage _currentPage = AppPage.home; // Track current page

  @override
  void initState() {
    super.initState();
    _loadLectures();
    // Initialize widgets when app starts
    Future.delayed(const Duration(seconds: 2), () async {
      await updateWidgets(null);
      await updateHomeScreenWidget(null);
    });
  }

  void _navigateToPage(AppPage page) {
    Navigator.pop(context); // Close drawer
    if (_currentPage == page && page != AppPage.home) { // Avoid re-navigating to same page unless it's home for a refresh
        // If it's already the current page (and not home), do nothing or maybe refresh
        return;
    }

    setState(() {
      _currentPage = page;
    });

    switch (page) {
      case AppPage.home:
        // Already on home or navigate to home (often means rebuilding current page)
        // If HomePage is complex, you might want a more specific refresh
        if (ModalRoute.of(context)?.settings.name != '/') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(
                prefs: widget.prefs,
                settings: widget.settings,
                onSettingsChanged: widget.onSettingsChanged,
              ),
              settings: const RouteSettings(name: '/'), // Optional: for route tracking
            ),
          );
        }
        break;
      case AppPage.dashboard:
        Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisPage(lectures: lectures))).then((_) => setState(() => _currentPage = AppPage.home));
        break;
      case AppPage.studyTimer:
        Navigator.push(context, MaterialPageRoute(builder: (_) => StudyTimerPage())).then((_) => setState(() => _currentPage = AppPage.home));
        break;
      case AppPage.studyCalendar:
        Navigator.push(context, MaterialPageRoute(builder: (_) => StudyCalendarPage())).then((_) => setState(() => _currentPage = AppPage.home));
        break;
      case AppPage.flashcards:
        Navigator.push(context, MaterialPageRoute(builder: (_) => FlashcardsPage())).then((_) => setState(() => _currentPage = AppPage.home));
        break;
      case AppPage.settings:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SettingsPage(
              settings: widget.settings,
              onSettingsChanged: widget.onSettingsChanged,
            ),
          ),
        ).then((_) {
          _loadLectures(); // Reload lectures in case settings affect them
          setState(() => _currentPage = AppPage.home);
        });
        break;
      case AppPage.aboutMe:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutMePage())).then((_) => setState(() => _currentPage = AppPage.home));
        break;
      case AppPage.backupRestore:
        // This is an ExpansionTile, selection handled differently or not at all for the tile itself
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isDark != widget.settings.isDarkMode) {
      setState(() {
        _isDark = widget.settings.isDarkMode;
      });
    }
  }

  Future<void> _loadLectures() async {
    try {
      final String? lecturesJson = widget.prefs.getString(_lecturesKey);
      if (lecturesJson != null) {
        final List<dynamic> decoded = jsonDecode(lecturesJson);
        setState(() {
          lectures = decoded.map((item) => Lecture.fromJson(item)).toList();
          _sortLectures();
        });

        // Verify PDF paths after loading
        await _verifyPDFPaths(lectures);
      }
    } catch (e) {
      print('Error loading lectures: $e');
    }
  }

  Future<void> _saveLectures() async {
    try {
      final String encodedData = jsonEncode(
        lectures.map((e) => e.toJson()).toList(),
      );
      await widget.prefs.setString(_lecturesKey, encodedData);

      // Update widgets immediately after saving
      print('Lectures saved, updating widgets...');
      await updateWidgets(null);
      await updateHomeScreenWidget(null); // Make sure both widgets are updated
    } catch (e) {
      print('Error saving lectures: $e');
    }
  }

  void addLecture(String name, String subtitle, String classroom) {
    setState(() {
      lectures.add(Lecture(
        name: name,
        subtitle: subtitle,
        classroom: classroom,
      ));
      _sortLectures();
    });
    _saveLectures();
  }

  void editLecture(String id, String newName) {
    setState(() {
      final index = lectures.indexWhere((lecture) => lecture.id == id);
      if (index != -1) {
        lectures[index].name = newName;
        _sortLectures();
      }
    });
    _saveLectures();
  }

  void deleteLecture(String id) {
    setState(() {
      lectures.removeWhere((lecture) => lecture.id == id);
    });
    _saveLectures();
  }

  void _sortLectures() {
    setState(() {
      if (_sortBy == 'name') {
        lectures.sort((a, b) {
          // Extract numbers from lecture names
          final aMatch = RegExp(r'(\d+)').firstMatch(a.name);
          final bMatch = RegExp(r'(\d+)').firstMatch(b.name);

          if (aMatch != null && bMatch != null) {
            // If both names contain numbers, sort numerically
            return int.parse(aMatch.group(1)!)
                .compareTo(int.parse(bMatch.group(1)!));
          } else if (aMatch != null) {
            return -1; // Names with numbers come first
          } else if (bMatch != null) {
            return 1;
          } else {
            // If no numbers, sort alphabetically
            return a.name
                .toLowerCase()
                .compareTo(b.name.toLowerCase()); // Case-insensitive sort
          }
        });
      } else {
        lectures.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      }
    });
  }

  void addTheoryLecture(String lectureId, PDFLecture pdfLecture) {
    setState(() {
      final index = lectures.indexWhere((lecture) => lecture.id == lectureId);
      if (index != -1) {
        // Check if a lecture with the same ID already exists
        if (!lectures[index].theoryLectures.any((l) => l.id == pdfLecture.id)) {
          lectures[index].theoryLectures.add(pdfLecture);
        }
      }
    });
    _saveLectures();
  }

  void addPracticalLecture(String lectureId, PDFLecture pdfLecture) {
    setState(() {
      final index = lectures.indexWhere((lecture) => lecture.id == lectureId);
      if (index != -1) {
        // Check if a lecture with the same ID already exists
        if (!lectures[index]
            .practicalLectures
            .any((l) => l.id == pdfLecture.id)) {
          lectures[index].practicalLectures.add(pdfLecture);
        }
      }
    });
    _saveLectures();
  }

  void updateTheoryLecture(String lectureId, PDFLecture pdfLecture) {
    setState(() {
      final lectureIndex =
          lectures.indexWhere((lecture) => lecture.id == lectureId);
      if (lectureIndex != -1) {
        final theoryIndex = lectures[lectureIndex]
            .theoryLectures
            .indexWhere((theory) => theory.id == pdfLecture.id);
        if (theoryIndex != -1) {
          lectures[lectureIndex].theoryLectures[theoryIndex] = pdfLecture;
        }
      }
    });
    _saveLectures();
  }

  void updatePracticalLecture(String lectureId, PDFLecture pdfLecture) {
    setState(() {
      final lectureIndex =
          lectures.indexWhere((lecture) => lecture.id == lectureId);
      if (lectureIndex != -1) {
        final practicalIndex = lectures[lectureIndex]
            .practicalLectures
            .indexWhere((practical) => practical.id == pdfLecture.id);
        if (practicalIndex != -1) {
          lectures[lectureIndex].practicalLectures[practicalIndex] = pdfLecture;
        }
      }
    });
    _saveLectures();
  }

  void deleteTheoryLecture(String lectureId, String pdfLectureId) {
    setState(() {
      final lectureIndex =
          lectures.indexWhere((lecture) => lecture.id == lectureId);
      if (lectureIndex != -1) {
        lectures[lectureIndex]
            .theoryLectures
            .removeWhere((l) => l.id == pdfLectureId);
      }
    });
    _saveLectures();
  }

  void deletePracticalLecture(String lectureId, String pdfLectureId) {
    setState(() {
      final lectureIndex =
          lectures.indexWhere((lecture) => lecture.id == lectureId);
      if (lectureIndex != -1) {
        lectures[lectureIndex]
            .practicalLectures
            .removeWhere((l) => l.id == pdfLectureId);
      }
    });
    _saveLectures();
  }


  Widget _buildAnalyticsSummary() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    
    int totalTheory = 0;
    int completedTheory = 0;
    int totalPractical = 0;
    int completedPractical = 0;

    for (var lecture in lectures) {
      totalTheory += lecture.theoryLectures.length;
      completedTheory +=
          lecture.theoryLectures.where((l) => l.isCompleted).length;
      totalPractical += lecture.practicalLectures.length;
      completedPractical +=
          lecture.practicalLectures.where((l) => l.isCompleted).length;
    }

    final totalProgress = (totalTheory + totalPractical) > 0
        ? (completedTheory + completedPractical) / (totalTheory + totalPractical)
        : 0.0;
    final theoryProgress =
        totalTheory > 0 ? completedTheory / totalTheory : 0.0;
    final practicalProgress =
        totalPractical > 0 ? completedPractical / totalPractical : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      constraints: const BoxConstraints(
        minWidth: double.infinity,
      ),
      child: Material(
        elevation: 0,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with overall stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Progress',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${completedTheory + completedPractical} of ${totalTheory + totalPractical} completed',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: totalProgress,
                          backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            totalProgress >= 0.8 ? Colors.green : primaryColor,
                          ),
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                        ),
                        Text(
                          '${(totalProgress * 100).toInt()}%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Progress breakdown cards
              Row(
                children: [
                  Expanded(
                    child: _buildProgressCard(
                      'Theory',
                      completedTheory,
                      totalTheory,
                      theoryProgress,
                      const Color(0xFF3B82F6),
                      Icons.menu_book_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildProgressCard(
                      'Practical',
                      completedPractical,
                      totalPractical,
                      practicalProgress,
                      const Color(0xFFF59E0B),
                      Icons.science_outlined,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AnalysisPage(lectures: lectures)),
                    );
                  },
                  icon: const Icon(Icons.analytics_outlined, size: 20),
                  label: const Text('Detailed Analytics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(String title, int completed, int total, double progress, Color color, IconData icon) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$completed',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            'of $total completed',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}% complete',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creating backup...')),
      );

      // Get Downloads directory
      final downloadsDir = Directory('/storage/emulated/0/Download');

      // Create a zip archive
      final archive = Archive();

      // Add lectures data to archive
      final lecturesJson = widget.prefs.getString('lectures');
      if (lecturesJson != null) {
        print('Adding lectures to backup: ${lecturesJson.length} bytes');
        final lecturesFile = ArchiveFile(
          'lectures.json',
          lecturesJson.length,
          utf8.encode(lecturesJson),
        );
        archive.addFile(lecturesFile);
      }

      // Add calendar events data
      final eventsJson = widget.prefs.getString('calendar_events');
      if (eventsJson != null) {
        print('Adding calendar events to backup: ${eventsJson.length} bytes');
        final eventsFile = ArchiveFile(
          'calendar_events.json',
          eventsJson.length,
          utf8.encode(eventsJson),
        );
        archive.addFile(eventsFile);
      }

      // Add flashcards data
      final flashcardsJson = widget.prefs.getString('flashcards');
      if (flashcardsJson != null) {
        print('Adding flashcards to backup: ${flashcardsJson.length} bytes');
        final flashcardsFile = ArchiveFile(
          'flashcards.json',
          flashcardsJson.length,
          utf8.encode(flashcardsJson),
        );
        archive.addFile(flashcardsFile);
      }

      // Add settings data to archive
      final settingsJson = widget.prefs.getString('settings');
      if (settingsJson != null) {
        print('Adding settings to backup: ${settingsJson.length} bytes');
        final settingsFile = ArchiveFile(
          'settings.json',
          settingsJson.length,
          utf8.encode(settingsJson),
        );
        archive.addFile(settingsFile);
      }

      // Add PDF files to archive
      int pdfCount = 0;
      for (var lecture in lectures) {
        for (var theory in lecture.theoryLectures) {
          if (theory.pdfPath != null) {
            final pdfFile = File(theory.pdfPath!);
            if (await pdfFile.exists()) {
              final pdfBytes = await pdfFile.readAsBytes();
              print(
                  'Adding theory PDF: ${theory.name} (${pdfBytes.length} bytes)');
              final archiveFile = ArchiveFile(
                'pdfs/${path.basename(theory.pdfPath!)}',
                pdfBytes.length,
                pdfBytes,
              );
              archive.addFile(archiveFile);
              pdfCount++;
            }
          }
        }
        for (var practical in lecture.practicalLectures) {
          if (practical.pdfPath != null) {
            final pdfFile = File(practical.pdfPath!);
            if (await pdfFile.exists()) {
              final pdfBytes = await pdfFile.readAsBytes();
              print(
                  'Adding practical PDF: ${practical.name} (${pdfBytes.length} bytes)');
              final archiveFile = ArchiveFile(
                'pdfs/${path.basename(practical.pdfPath!)}',
                pdfBytes.length,
                pdfBytes,
              );
              archive.addFile(archiveFile);
              pdfCount++;
            }
          }
        }
      }

      if (archive.files.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to backup')),
        );
        return;
      }

      // Save the zip file to Downloads directory
      final zipData = ZipEncoder().encode(archive);
      if (zipData != null) {
        final backupFileName =
            'wanakanm_backup_${DateTime.now().toIso8601String().split('T')[0]}.zip'; // Changed filename
        final backupFile = File(path.join(downloadsDir.path, backupFileName));

        await backupFile.writeAsBytes(zipData);
        print('Backup saved to: ${backupFile.path}');
        print('Backup size: ${zipData.length} bytes');
        print('PDFs included: $pdfCount');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved to Downloads: $backupFileName'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => OpenFile.open(
                  downloadsDir.path), // Open Downloads, not specific file
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error creating backup: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating backup: $e'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restoring backup...')),
        );

        final file = File(result.files.first.path!);
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        // Get app directory for storing PDFs
        final appDir = await getApplicationDocumentsDirectory();

        // Create a temporary map to store old path to new path mappings
        Map<String, String> pathMappings = {};

        // First, extract all PDFs and create path mappings
        for (final file in archive.files) {
          if (file.name.startsWith('pdfs/')) {
            final newPath = path.join(appDir.path, file.name);
            final newFile = File(newPath);

            await newFile.parent.create(recursive: true);
            await newFile.writeAsBytes(file.content as List<int>);

            final filename = path.basename(file.name);
            pathMappings[filename] = newPath;
          }
        }

        // Restore all data files
        for (final file in archive.files) {
          if (file.name.startsWith('pdfs/')) {
            continue; // Skip PDF files as they're already handled
          }

          try {
            // Only try to decode as UTF-8 for JSON files
            if (file.name.endsWith('.json')) {
              final content = utf8.decode(file.content as List<int>);

              switch (file.name) {
                case 'lectures.json':
                  // Update PDF paths in lectures data
                  final decodedLectures = jsonDecode(content) as List;
                  final updatedLectures = decodedLectures.map((lectureJson) {
                    var updatedLecture = Map<String, dynamic>.from(lectureJson);

                    // Update theory lectures paths
                    if (updatedLecture['theoryLectures'] != null) {
                      updatedLecture['theoryLectures'] =
                          (updatedLecture['theoryLectures'] as List)
                              .map((theory) {
                        var updatedTheory = Map<String, dynamic>.from(theory);
                        if (theory['pdfPath'] != null) {
                          final filename = path.basename(theory['pdfPath']);
                          updatedTheory['pdfPath'] = pathMappings[filename];
                        }
                        return updatedTheory;
                      }).toList();
                    }

                    // Update practical lectures paths
                    if (updatedLecture['practicalLectures'] != null) {
                      updatedLecture['practicalLectures'] =
                          (updatedLecture['practicalLectures'] as List)
                              .map((practical) {
                        var updatedPractical =
                            Map<String, dynamic>.from(practical);
                        if (practical['pdfPath'] != null) {
                          final filename = path.basename(practical['pdfPath']);
                          updatedPractical['pdfPath'] = pathMappings[filename];
                        }
                        return updatedPractical;
                      }).toList();
                    }

                    return updatedLecture;
                  }).toList();
                  await widget.prefs
                      .setString('lectures', jsonEncode(updatedLectures));
                  break;

                case 'calendar_events.json':
                  await widget.prefs.setString('calendar_events', content);
                  break;

                case 'flashcards.json':
                  await widget.prefs.setString('flashcards', content);
                  break;

                case 'settings.json':
                  await widget.prefs.setString('settings', content);
                  break;
              }
            }
          } catch (e, stackTrace) {
            print('Error processing file ${file.name}: $e');
            print('Stack trace: $stackTrace');
            // Continue processing other files even if one fails
            continue;
          }
        }

        // Reload all data
        await _loadLectures();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restored successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error restoring backup: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error restoring backup: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyPDFPaths(List<Lecture> lectures) async {
    bool hasInvalidPaths = false;

    for (var lecture in lectures) {
      // Check theory lectures
      for (var theory in lecture.theoryLectures) {
        if (theory.pdfPath != null) {
          final file = File(theory.pdfPath!);
          if (!await file.exists()) {
            print('Invalid theory PDF path: ${theory.pdfPath}');
            hasInvalidPaths = true;
          }
        }
      }

      // Check practical lectures
      for (var practical in lecture.practicalLectures) {
        if (practical.pdfPath != null) {
          final file = File(practical.pdfPath!);
          if (!await file.exists()) {
            print('Invalid practical PDF path: ${practical.pdfPath}');
            hasInvalidPaths = true;
          }
        }
      }
    }

    if (hasInvalidPaths && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Some PDF files could not be found. They may need to be re-added.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      drawer: _buildDrawer(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text('WANAKANM'),
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 4.0,
            surfaceTintColor: theme.colorScheme.surface,
            shadowColor: theme.shadowColor.withOpacity(0.1),
          ),
          // Quick Access Tools Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.psychology_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Study Tools',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildStudyToolsGrid(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Progress Overview
          if (lectures.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.trending_up,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Your Progress',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildAnalyticsSummary(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          // Lectures Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.menu_book,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'My Lectures',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      setState(() {
                        _sortBy = value;
                        _sortLectures();
                      });
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'name',
                        child: Text('Sort by Name'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'date',
                        child: Text('Sort by Date Added'),
                      ),
                    ],
                    icon: Icon(Icons.sort, color: theme.colorScheme.primary),
                    tooltip: "Sort Lectures",
                  ),
                ],
              ),
            ),
          ),
          // Lectures List or Empty State
          lectures.isEmpty
              ? SliverToBoxAdapter(
                  child: _buildEmptyLecturesState(context),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final lecture = lectures[index];
                        return _buildModernLectureCard(lecture);
                      },
                      childCount: lectures.length,
                    ),
                  ),
                ),
          // Bottom spacing for FAB
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddLecturePage(onAdd: addLecture),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Lecture'),
        tooltip: 'Add New Lecture',
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }

  void _showLectureOptions(BuildContext context, Lecture lecture) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return Wrap(
            children: <Widget>[
              ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit Details'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(lecture);
                  }),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red[400]),
                title: Text('Delete Lecture',
                    style: TextStyle(color: Colors.red[400])),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmationDialog(lecture);
                },
              ),
            ],
          );
        });
  }

  void _showDeleteConfirmationDialog(Lecture lecture) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lecture'),
        content: Text(
            'Are you sure you want to delete "${lecture.name}" and all its contents? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              deleteLecture(lecture.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${lecture.name}" deleted.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Lecture lecture) {
    final nameController = TextEditingController(text: lecture.name);
    final subtitleController = TextEditingController(text: lecture.subtitle);
    final classroomController = TextEditingController(text: lecture.classroom);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Lecture'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Lecture Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: subtitleController,
                decoration: const InputDecoration(labelText: 'Course Info'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: classroomController,
                decoration: const InputDecoration(labelText: 'Classroom'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                final index = lectures.indexWhere((l) => l.id == lecture.id);
                if (index != -1) {
                  lectures[index].name = nameController.text;
                  lectures[index].subtitle = subtitleController.text;
                  lectures[index].classroom = classroomController.text;
                  _sortLectures();
                }
              });
              _saveLectures();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyToolsGrid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = (width ~/ 170).clamp(2, 4);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildToolCard(
          context: context,
          title: 'AI Study Tools',
          subtitle: 'Generate summaries & quizzes',
          icon: Icons.psychology,
          gradient: [Colors.purple, Colors.deepPurple],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AIToolsPage(
                text: 'Welcome to AI Study Tools',
                performAiAction: (text, action, {questionCount, quizType, difficulty}) {},
                lectureId: '',
                lectureName: 'General',
              )),
            );
          },
        ),
        _buildToolCard(
          context: context,
          title: 'Flashcards',
          subtitle: 'Practice with smart cards',
          icon: Icons.style,
          gradient: [Colors.orange, Colors.deepOrange],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FlashcardsPage()),
            );
          },
        ),
        _buildToolCard(
          context: context,
          title: 'Study Calendar',
          subtitle: 'Schedule & track events',
          icon: Icons.calendar_today,
          gradient: [Colors.blue, Colors.indigo],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => StudyCalendarPage()),
            );
          },
        ),
        _buildToolCard(
          context: context,
          title: 'Study Timer',
          subtitle: 'Focus with Pomodoro',
          icon: Icons.timer,
          gradient: [Colors.green, Colors.teal],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => StudyTimerPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.2),
        highlightColor: Colors.white.withOpacity(0.05),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLecturesState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.school_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Lectures Yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first lecture to begin organizing your study materials',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddLecturePage(onAdd: addLecture),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Lecture'),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLectureCard(Lecture lecture) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    
    int totalTheory = lecture.theoryLectures.length;
    int completedTheory = lecture.theoryLectures.where((l) => l.isCompleted).length;
    int totalPractical = lecture.practicalLectures.length;
    int completedPractical = lecture.practicalLectures.where((l) => l.isCompleted).length;
    int total = totalTheory + totalPractical;
    int completed = completedTheory + completedPractical;
    double progress = total == 0 ? 0 : completed / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: 0,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LectureDetailPage(
                  lecture: lecture,
                  onAddTheory: addTheoryLecture,
                  onAddPractical: addPracticalLecture,
                  onUpdateTheory: updateTheoryLecture,
                  onUpdatePractical: updatePracticalLecture,
                  onDeleteTheory: deleteTheoryLecture,
                  onDeletePractical: deletePracticalLecture,
                ),
              ),
            ).then((_) => _loadLectures());
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lecture.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (lecture.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              lecture.subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                          if (lecture.classroom.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  lecture.classroom,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                backgroundColor: theme.colorScheme.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress == 1.0 ? Colors.green : theme.colorScheme.primary,
                                ),
                                strokeWidth: 6,
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          onSelected: (value) => _showLectureOptions(context, lecture),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniProgressBar(
                        'Theory',
                        completedTheory,
                        totalTheory,
                        const Color(0xFF3B82F6), // Same blue as progress cards
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMiniProgressBar(
                        'Practical',
                        completedPractical,
                        totalPractical,
                        const Color(0xFFF59E0B), // Same yellow/orange as progress cards
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniProgressBar(String label, int completed, int total, Color color) {
    final theme = Theme.of(context);
    final progress = total == 0 ? 0.0 : completed / total;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$completed',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 20,
          ),
        ),
        Text(
          'of $total completed',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).toInt()}% complete',
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }


  Widget _buildDrawerSectionHeader(BuildContext context, String title) {
    return Padding(
      // Increased top padding for more separation
      padding: const EdgeInsets.only(left: 16.0, top: 20.0, bottom: 8.0, right: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13, // Slightly larger for better readability
          fontWeight: FontWeight.w600, // Medium bold
          color: Theme.of(context).colorScheme.primary.withOpacity(0.85), // More vibrant
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
      BuildContext context, IconData icon, String title, VoidCallback onTap,
      {bool selected = false}) {
    return ListTile(
      leading: Icon(icon, color: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).iconTheme.color),
      title: Text(title,
          style: TextStyle(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).textTheme.bodyLarge?.color)),
      onTap: onTap,
      selected: selected,
      selectedColor: Theme.of(context).colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      selectedTileColor:
          Theme.of(context).colorScheme.primary.withOpacity(0.1),
    );
  }

  Widget _buildDrawerSubItem(
      BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: const SizedBox(width: 8), // Indent sub items
      title: Row(
        children: [
          Icon(icon,
              size: 20, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 16),
          Text(title),
        ],
      ),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.only(left: 32.0),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        // Use Column to add version at bottom
        children: [
          Expanded(
            // Make ListView expand
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/icons/logo.png', // Assuming this is the correct path
                            height: 40,
                            width: 40,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'WANAKANM',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your Study Companion',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                // --- Main Section ---
                _buildDrawerSectionHeader(context, 'MAIN'),
                _buildDrawerItem(
                  context,
                  Icons.home_outlined,
                  'Home',
                  () => _navigateToPage(AppPage.home),
                  selected: _currentPage == AppPage.home,
                ),

                // --- Study Tools Section ---
                _buildDrawerSectionHeader(context, 'STUDY TOOLS'),
                _buildDrawerItem(
                  context,
                  Icons.analytics_outlined,
                  'Dashboard',
                  () => _navigateToPage(AppPage.dashboard),
                  selected: _currentPage == AppPage.dashboard,
                ),
                _buildDrawerItem(
                  context,
                  Icons.timer_outlined,
                  'Study Timer',
                  () => _navigateToPage(AppPage.studyTimer),
                  selected: _currentPage == AppPage.studyTimer,
                ),
                _buildDrawerItem(
                  context,
                  Icons.calendar_today_outlined,
                  'Study Calendar',
                  () => _navigateToPage(AppPage.studyCalendar),
                  selected: _currentPage == AppPage.studyCalendar,
                ),
                _buildDrawerItem(
                  context,
                  Icons.style_outlined,
                  'Flashcards',
                  () => _navigateToPage(AppPage.flashcards),
                  selected: _currentPage == AppPage.flashcards,
                ),

                // --- Data Management Section ---
                _buildDrawerSectionHeader(context, 'DATA MANAGEMENT'),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const ValueKey('backup_restore_expansion'),
                    leading: Icon(
                      Icons.backup_outlined, 
                      color: Theme.of(context).iconTheme.color ?? 
                            Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)
                    ),
                    title: Text(
                      'Backup & Restore',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 14.5,
                      ),
                    ),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0),
                    childrenPadding: const EdgeInsets.only(left: 0),
                    children: <Widget>[
                      _buildDrawerSubItem(
                        context, 
                        Icons.save_alt_outlined, 
                        'Create Backup', 
                        () {
                          Navigator.pop(context);
                          _createBackup();
                        },
                      ),
                      _buildDrawerSubItem(
                        context, 
                        Icons.restore_outlined, 
                        'Restore Backup', 
                        () {
                          Navigator.pop(context);
                          _restoreBackup();
                        },
                      ),
                    ],
                  ),
                ),

                // --- App Section ---
                _buildDrawerSectionHeader(context, 'APP'),
                _buildDrawerItem(
                  context,
                  Icons.settings_outlined,
                  'Settings',
                  () => _navigateToPage(AppPage.settings),
                  selected: _currentPage == AppPage.settings,
                ),
                _buildDrawerItem(
                  context,
                  Icons.person_outline,
                  'About Me',
                  () => _navigateToPage(AppPage.aboutMe),
                  selected: _currentPage == AppPage.aboutMe,
                ),
              ],
            ),
          ),
          // Version info at the bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Version 1.0.1', // Incremented version
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class AddLecturePage extends StatefulWidget {
  final Function(String, String, String) onAdd;

  const AddLecturePage({super.key, required this.onAdd});

  @override
  State<AddLecturePage> createState() => _AddLecturePageState();
}

class _AddLecturePageState extends State<AddLecturePage> {
  final _nameController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _classroomController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Add form key

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    _classroomController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    bool isRequired = false,
  }) {
    return TextFormField(
      // Use TextFormField
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon),
        // No need for border/fill here, it comes from theme
      ),
      validator: isRequired
          ? (value) {
              if (value == null || value.isEmpty) {
                return '$labelText is required';
              }
              return null;
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Lecture'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          // Wrap in Form
          key: _formKey,
          child: ListView(
            // Use ListView
            children: [
              Text(
                'Lecture Information',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _nameController,
                labelText: 'Lecture Name *',
                hintText: 'e.g., Anatomy Lecture 1',
                icon: Icons.book_outlined,
                isRequired: true, // Mark as required
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _subtitleController,
                labelText: 'Course Information',
                hintText: 'e.g., VET_MED_S1_24/25',
                icon: Icons.school_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _classroomController,
                labelText: 'Classroom',
                hintText: 'e.g., Main Hall',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                // Use ElevatedButton
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Validate form
                    widget.onAdd(
                      _nameController.text,
                      _subtitleController.text,
                      _classroomController.text,
                    );
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('Save Lecture'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '* Required field',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LectureDetailPage extends StatefulWidget {
  final Lecture lecture;
  final Function(String, PDFLecture) onAddTheory;
  final Function(String, PDFLecture) onAddPractical;
  final Function(String, PDFLecture) onUpdateTheory;
  final Function(String, PDFLecture) onUpdatePractical;
  final Function(String, String) onDeleteTheory;
  final Function(String, String) onDeletePractical;

  const LectureDetailPage({
    super.key,
    required this.lecture,
    required this.onAddTheory,
    required this.onAddPractical,
    required this.onUpdateTheory,
    required this.onUpdatePractical,
    required this.onDeleteTheory,
    required this.onDeletePractical,
  });

  @override
  State<LectureDetailPage> createState() => _LectureDetailPageState();
}

class _LectureDetailPageState extends State<LectureDetailPage> {
  // --- ADDED FOR AI FEATURES ---
  late final AiService _aiService;
  String? _currentPdfText; // To store extracted text for the currently selected PDF
  String? _currentPdfPath; // To track which PDF's text is cached
  bool _isProcessingAi = false; // To show loading indicators for AI tasks
  // --- END ADDED ---

  @override
  void initState() {
    super.initState();
    _aiService = AiService(apiKey: 'AIzaSyAiO8RVja7tRdsWMI0RjKDeB8zAt9bGWHk');
    // --- END ADDED ---
  }

  Future<void> _pickAndSavePDF(bool isTheory) async {
    try {
      // Check permissions first
      if (Platform.isAndroid) {
        bool hasPermission = false;

        var storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) hasPermission = true;

        if (!hasPermission) {
          storageStatus = await Permission.storage.request();
          hasPermission = storageStatus.isGranted;
        }
        // Try manage external storage if regular storage isn't enough (Android 11+)
        if (!hasPermission) {
           var manageStatus = await Permission.manageExternalStorage.status;
           if(manageStatus.isGranted) hasPermission = true;
           else {
             manageStatus = await Permission.manageExternalStorage.request();
             hasPermission = manageStatus.isGranted;
           }
        }

        if (!hasPermission) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Storage permission is required to pick PDF files. Please grant it in settings.'),
                backgroundColor: Colors.red),
          );
          return;
        }
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        final file = result.files.first;
        final name = file.name.replaceAll('.pdf', '');
        final appDir = await getApplicationDocumentsDirectory();
        final pdfsDir = Directory('${appDir.path}/pdfs');
        await pdfsDir.create(recursive: true);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final savedFile = File('${pdfsDir.path}/$fileName');

        if (file.path != null) {
          await File(file.path!).copy(savedFile.path);
        }

        final pdfLecture = PDFLecture(name: name, pdfPath: savedFile.path);

        if (isTheory) {
          widget.onAddTheory(widget.lecture.id, pdfLecture);
        } else {
          widget.onAddPractical(widget.lecture.id, pdfLecture);
        }

        setState(() {}); // Refresh UI
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF added successfully')),
        );
      }
    } catch (e) {
      print('Error picking PDF: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving PDF file: $e')),
      );
    }
  }

  Future<void> _openPDF(String? pdfPath) async {
     try {
      if (pdfPath == null || pdfPath.isEmpty) {
        print('Error: PDF path is null or empty');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: PDF file not found'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      final file = File(pdfPath);
      if (!await file.exists()) {
        print('Error: PDF file does not exist at path: $pdfPath');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: PDF file not found. It might have been moved or deleted.'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      final result = await OpenFile.open(pdfPath);
      if (result.type != "done") {
        print('Error opening PDF: ${result.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening PDF: ${result.message}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Exception while opening PDF: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleCompletion(PDFLecture pdfLecture) {
    final updatedLecture = PDFLecture(
      id: pdfLecture.id,
      name: pdfLecture.name,
      pdfPath: pdfLecture.pdfPath,
      dateAdded: pdfLecture.dateAdded,
      isCompleted: !pdfLecture.isCompleted,
    );
    if (widget.lecture.theoryLectures.any((l) => l.id == pdfLecture.id)) {
      widget.onUpdateTheory(widget.lecture.id, updatedLecture);
    } else {
      widget.onUpdatePractical(widget.lecture.id, updatedLecture);
    }
    setState(() {
      final theoryIndex = widget.lecture.theoryLectures.indexWhere((l) => l.id == pdfLecture.id);
      if (theoryIndex != -1) widget.lecture.theoryLectures[theoryIndex] = updatedLecture;
      final practicalIndex = widget.lecture.practicalLectures.indexWhere((l) => l.id == pdfLecture.id);
      if (practicalIndex != -1) widget.lecture.practicalLectures[practicalIndex] = updatedLecture;
    });
    updateWidgets(null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(updatedLecture.isCompleted ? 'Marked as completed' : 'Marked as incomplete'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showDeleteConfirmation(PDFLecture pdfLecture, bool isTheory) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lecture'),
        content: Text('Are you sure you want to delete "${pdfLecture.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            // --- MODIFIED: Make this function async ---
            onPressed: () async {
              // --- MODIFIED: Use try...catch ---
              try {
                if (pdfLecture.pdfPath != null) {
                  // Await the deletion within the try block
                  await File(pdfLecture.pdfPath!).delete();
                  print('Successfully deleted PDF: ${pdfLecture.pdfPath}');
                }
              } catch (e) {
                // Catch any errors during deletion
                print("Error deleting PDF file: $e");
                // Optionally, show a message to the user here
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text('Could not delete PDF file: $e'), backgroundColor: Colors.orange),
                // );
              }
              // --- END MODIFICATION ---

              // This part remains the same, deleting from the list/state
              if (isTheory) {
                widget.onDeleteTheory(widget.lecture.id, pdfLecture.id);
                setState(() {
                  widget.lecture.theoryLectures
                      .removeWhere((l) => l.id == pdfLecture.id);
                });
              } else {
                widget.onDeletePractical(widget.lecture.id, pdfLecture.id);
                setState(() {
                  widget.lecture.practicalLectures
                      .removeWhere((l) => l.id == pdfLecture.id);
                });
              }
              Navigator.pop(context); // Close the dialog

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lecture deleted'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            // --- END MODIFICATION ---
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // --- ADDED/MODIFIED FOR AI FEATURES ---

  Future<String?> _getOrExtractPdfText(String? pdfPath) async {
    if (pdfPath == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('PDF path is missing.'), backgroundColor: Colors.red),
       );
       return null;
    }
    if (_currentPdfText != null && _currentPdfPath == pdfPath) {
      return _currentPdfText;
    }

    setState(() => _isProcessingAi = true);
    final extractedText = await _aiService.extractPdfText(pdfPath);
    setState(() => _isProcessingAi = false);

    if (extractedText == null || extractedText.trim().isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not extract text from PDF. It might be image-based or protected.'), backgroundColor: Colors.orange),
        );
      }
      _currentPdfText = null;
      _currentPdfPath = null;
      return null;
    }

    _currentPdfText = extractedText;
    _currentPdfPath = pdfPath;
    return _currentPdfText;
  }

  void _showAiOptions(BuildContext context, String? pdfPath) async {
    final text = await _getOrExtractPdfText(pdfPath);
    if (text == null || !mounted) return;

    // Use a full page instead of a modal bottom sheet to avoid rendering glitches
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AIToolsPage(
          text: text,
          performAiAction: _performAiAction,
          lectureId: widget.lecture.id,
          lectureName: widget.lecture.name,
        ),
      ),
    );
  }

  void _performAiAction(String pdfText, String action, {int? questionCount = 10, String? quizType = 'mixed', String? difficulty = 'medium'}) async {
    // Get the PDF name from the current PDF path
    String? pdfName;
    if (_currentPdfPath != null) {
      final pdfFile = File(_currentPdfPath!);
      if (pdfFile.existsSync()) {
        // Extract just the filename without extension
        pdfName = pdfFile.path.split('/').last.split('\\').last;
        if (pdfName.contains('.pdf')) {
          pdfName = pdfName.substring(0, pdfName.lastIndexOf('.pdf'));
        }
        // Remove timestamp prefix if it exists (from the format we use when saving PDFs)
        if (pdfName.contains('_')) {
          final parts = pdfName.split('_');
          if (parts.length > 1 && int.tryParse(parts[0]) != null) {
            // If the first part is a number (timestamp), remove it
            pdfName = parts.sublist(1).join('_');
          }
        }
      }
    }
    setState(() => _isProcessingAi = true);
    String? result;
    String title = '';
    List<Map<String, String>>? flashcards;
    Map<String, String>? studyGuide;

    // Ensure non-null values for parameters
    final int nonNullQuestionCount = questionCount ?? 10;
    final String nonNullQuizType = quizType ?? 'mixed';

    // Use the quiz type directly now that we have a separate difficulty parameter
    String baseQuizType = nonNullQuizType;
    String difficultyLevel = difficulty ?? 'medium';

    try {
      switch (action) {
        case 'comprehensive_guide':
          title = 'Comprehensive Study Guide';
          studyGuide = await _aiService.generateComprehensiveStudyGuide(pdfText);
          // Create a preview of the study guide
          if (studyGuide != null && studyGuide.isNotEmpty) {
            result = 'Generated a complete study guide with the following sections:\n\n';
            if (studyGuide.containsKey('summary')) {
              result += '• Summary\n';
            }
            if (studyGuide.containsKey('important_topics')) {
              result += '• Important Topics\n';
            }
            if (studyGuide.containsKey('key_terms')) {
              result += '• Key Terms\n';
            }
            if (studyGuide.containsKey('study_roadmap')) {
              result += '• Study Roadmap\n';
            }
            if (studyGuide.containsKey('discussion_questions')) {
              result += '• Discussion Questions\n';
            }
          }
          break;
        case 'summary':
          title = 'Summary';
          result = await _aiService.summarizePdf(pdfText);
          break;
        case 'key_points':
          title = 'Key Points';
          result = await _aiService.getKeyPoints(pdfText);
          break;
        case 'important_topics':
          title = 'Important Topics';
          result = await _aiService.getImportantTopics(pdfText);
          break;
        case 'key_terms':
          title = 'Key Terms';
          result = await _aiService.getKeyTerms(pdfText);
          break;
        case 'study_roadmap':
          title = 'Study Roadmap';
          result = await _aiService.getStudyRoadmap(pdfText);
          break;
        case 'discussion_questions':
          title = 'Discussion Questions';
          result = await _aiService.getDiscussionQuestions(pdfText);
          break;
        case 'flashcards':
          title = 'Flashcards';
          flashcards = await _aiService.generateFlashcards(pdfText, count: nonNullQuestionCount);

          // Add PDF name to each flashcard
          if (flashcards != null && pdfName != null) {
            for (var card in flashcards) {
              card['pdfName'] = pdfName;
            }
          }
          // Convert flashcards to a preview string for the dialog
          if (flashcards != null && flashcards.isNotEmpty) {
            result = 'Generated ${flashcards.length} flashcards:\n\n';
            for (int i = 0; i < min(3, flashcards.length); i++) {
              if (result != null) {
                result += 'Card ${i + 1}:\n';
                result += 'Front: ${flashcards[i]['front']}\n';
                result += 'Back: ${flashcards[i]['back']}\n\n';
              }
            }
            if (flashcards.length > 3 && result != null) {
              result += '...';
            }
          }
          break;
        case 'questions':
          title = 'Practice Questions';
          result = await _aiService.generateQuestions(pdfText, count: nonNullQuestionCount, type: nonNullQuizType, difficulty: difficultyLevel);
          break;
      }
    } finally {
      setState(() => _isProcessingAi = false);
    }

    if (mounted) {
      if (action == 'comprehensive_guide' && studyGuide != null && studyGuide.isNotEmpty) {
        // Save the study guide and go directly to the page without confirmation dialog
        final studyGuideService = StudyGuideService();
        final newGuide = StudyGuide(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'Study Guide for ${widget.lecture.name}',
            lectureId: widget.lecture.id,
            lectureName: widget.lecture.name,
            createdAt: DateTime.now(),
            content: studyGuide, // Removed null assertion operator
          );
          await studyGuideService.saveStudyGuide(newGuide);

          // Navigate to the study guide page
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudyGuidePage(
                  studyGuide: studyGuide as Map<String, String>, // Cast to required type
                  title: 'Study Guide for ${widget.lecture.name}',
                ),
              ),
            );
          }
      } else if (action == 'questions' && result != null) {
        // Process questions differently for multiple choice vs other types
        List<String> questions = [];

        if (baseQuizType == 'multiple_choice' || baseQuizType == 'mixed') {
          // For multiple choice, we need to include the options with each question
          final lines = result.split('\n');
          List<String> currentQuestion = [];

          for (int i = 0; i < lines.length; i++) {
            final line = lines[i].trim();

            // Start of a new question
            if (line.startsWith('Q: ')) {
              // If we have a previous question, add it to the list
              if (currentQuestion.isNotEmpty) {
                questions.add(currentQuestion.join('\n'));
                currentQuestion = [];
              }
              currentQuestion.add(line);
            } 
            // Option lines or CORRECT: line for the current question
            else if (line.startsWith('A)') || line.startsWith('B)') || 
                     line.startsWith('C)') || line.startsWith('D)') ||
                     line.startsWith('CORRECT:')) {
              if (currentQuestion.isNotEmpty) {
                currentQuestion.add(line);
              }
            }
            // Empty line - ignore
            else if (line.isEmpty) {
              continue;
            }
            // Other text might be part of the current question
            else if (currentQuestion.isNotEmpty) {
              // Only add if it's not just a separator or other formatting
              if (line.length > 1 && !line.startsWith('---')) {
                currentQuestion.add(line);
              }
            }
          }

          // Add the last question if there is one
          if (currentQuestion.isNotEmpty) {
            questions.add(currentQuestion.join('\n'));
          }
        } else {
          // For other question types, just get lines starting with Q:
          questions = result
              .split('\n')
              .where((line) => line.trim().startsWith('Q: '))
              .map((line) => line.trim())
              .toList();
        }

        if (questions.isNotEmpty && mounted) {
          // Skip preview dialog and go directly to the exam page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExamPage(
                questions: questions,
                pdfText: pdfText,
                aiService: _aiService,
                quizType: nonNullQuizType,
              ),
            ),
          );
        } else {
          _showResultDialog('No Questions', 'The AI did not generate any questions, or failed to format them. Please try again.\n\nRaw response: $result');
        }
      } else if (action == 'flashcards' && flashcards != null && flashcards.isNotEmpty) {
        // Go directly to the flashcards page without confirmation dialog
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FlashcardsPage(
                flashcards: flashcards,
                title: 'AI Generated Flashcards for ${widget.lecture.name}',
                lectureId: widget.lecture.id,
                // Pass the PDF name to the FlashcardsPage
              ),
            ),
          );
        }
      } else if (result != null) {
        _showResultDialog(title, result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get AI response.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Show a preview dialog with the option to proceed or cancel

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: 'Copy to clipboard',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            content,
            style: const TextStyle(height: 1.5),
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0.0),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(String title, List<PDFLecture> lectures) {
    int completedCount = lectures.where((lecture) => lecture.isCompleted).length;
    double progress = lectures.isEmpty ? 0 : completedCount / lectures.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              )),
              const SizedBox(width: 8),
              Text('$completedCount/${lectures.length}', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green : Theme.of(context).colorScheme.primary,
              ),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lecture.name),
      ),
      body: Stack( // Use Stack for loading overlay
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressIndicator('Theory:', widget.lecture.theoryLectures),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.1,
                  ),
                  itemCount: widget.lecture.theoryLectures.length + 1,
                  itemBuilder: (context, index) {
                    if (index == widget.lecture.theoryLectures.length) {
                      return _buildAddButton(true);
                    }
                    return _buildPDFCard(widget.lecture.theoryLectures[index], true);
                  },
                ),
                const SizedBox(height: 16),
                _buildProgressIndicator('Practical:', widget.lecture.practicalLectures),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.1,
                  ),
                  itemCount: widget.lecture.practicalLectures.length + 1,
                  itemBuilder: (context, index) {
                    if (index == widget.lecture.practicalLectures.length) {
                      return _buildAddButton(false);
                    }
                    return _buildPDFCard(widget.lecture.practicalLectures[index], false);
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          // Loading Overlay
          if (_isProcessingAi)
            Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withOpacity(0.6)
                  : Colors.white.withOpacity(0.6),
              child: Center(
                child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                       color: Theme.of(context).cardColor,
                       borderRadius: BorderRadius.circular(15),
                       boxShadow: [
                          BoxShadow(
                             color: Colors.black.withOpacity(0.1),
                             blurRadius: 10,
                             spreadRadius: 2,
                          )
                       ]
                    ),
                    child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20),
                          Text(
                             "AI is thinking...",
                             style: Theme.of(context).textTheme.titleMedium,
                          ),
                       ],
                    ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPDFCard(PDFLecture pdfLecture, bool isTheory) {
    final color = pdfLecture.isCompleted ? Colors.green : Theme.of(context).colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPDF(pdfLecture.pdfPath),
        onLongPress: () => _toggleCompletion(pdfLecture),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf_outlined, size: 60, color: color),
                  const SizedBox(height: 12),
                  Text(
                    pdfLecture.name,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      decoration: pdfLecture.isCompleted ? TextDecoration.lineThrough : null,
                      color: pdfLecture.isCompleted ? Colors.grey[600] : null,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Checkbox(
                value: pdfLecture.isCompleted,
                onChanged: (_) => _toggleCompletion(pdfLecture),
                activeColor: Colors.green,
                shape: const CircleBorder(),
                visualDensity: VisualDensity.compact,
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.redAccent[100]),
                onPressed: () => _showDeleteConfirmation(pdfLecture, isTheory),
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete Lecture',
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: IconButton(
                icon: Icon(Icons.psychology_outlined, color: Colors.purpleAccent[100]),
                onPressed: _isProcessingAi ? null : () => _showAiOptions(context, pdfLecture.pdfPath),
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'AI Study Tools',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(bool isTheory) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pickAndSavePDF(isTheory),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text('Add ${isTheory ? "Theory" : "Practical"}', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
