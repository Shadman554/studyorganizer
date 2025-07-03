import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/ai_tools_page.dart';
import 'pages/about_me_page.dart';
import 'pages/lecture_detail.dart';
import 'pages/study_timer_page.dart';
import 'pages/study_calendar_page.dart';
import 'pages/flashcards_page.dart';
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
import 'package:home_widget/home_widget.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'pages/analysis_page.dart';
import 'pages/settings_page.dart';

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