import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart'; // For accessing AppSettings

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
  Future<bool> _requestNotificationPermissions() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

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
