import 'package:flutter/material.dart';
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
                    dailyTaskCount: value,
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
                  child: Text(font,
                      style: TextStyle(
                        fontFamily: font == 'Default'
                            ? null
                            : font == 'Nrt Bold'
                                ? 'Nrt_bold'
                                : font == 'Nrt Regular'
                                    ? 'Nrt_regular'
                                    : font == 'K24'
                                        ? 'K24'
                                        : 'Speda',
                      )),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  final newSettings = AppSettings(
                    isDarkMode: widget.settings.isDarkMode,
                    dailyTaskCount: widget.settings.dailyTaskCount,
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
                    dailyTaskCount: widget.settings.dailyTaskCount,
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
                    width: 56, child: Icon(Icons.font_download_outlined)),
                title: const Text('App Font'),
                subtitle: Text(widget.settings.selectedFont),
                onTap: () => _showFontSelectionDialog(context),
                dense: true,
              ),
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