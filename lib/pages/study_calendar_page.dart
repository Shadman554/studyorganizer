
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
// Import necessary items from main.dart
import '../main.dart'
    show
        scheduleEventNotification,
        flutterLocalNotificationsPlugin,
        StudyEvent,
        EventType,
        getEventTypeText,
        getEventTypeIcon,
        getEventTypeColor; // Assuming these are now correctly defined in main.dart

class StudyCalendarPage extends StatefulWidget {
  const StudyCalendarPage({super.key});

  @override
  _StudyCalendarPageState createState() => _StudyCalendarPageState();
}

class _StudyCalendarPageState extends State<StudyCalendarPage> with TickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<StudyEvent>> _events = {};
  final String _eventsKey = 'calendar_events';
  bool _isDisposed = false;

  // For filtering
  EventType? _selectedEventTypeFilter;
  late AnimationController _filterChipAnimationController;
  late AnimationController _fabAnimationController;
  late AnimationController _listAnimationController;
  late Animation<double> _fabScaleAnimation;
  late Animation<Offset> _fabSlideAnimation;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
    
    // Initialize animation controllers
    _filterChipAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Setup animations
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );
    
    _fabSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOutBack));

    // Start animations
    _fabAnimationController.forward();
    _listAnimationController.forward();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _filterChipAnimationController.dispose();
    _fabAnimationController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    if (_isDisposed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getString(_eventsKey);
      if (eventsJson != null && mounted) {
        final Map<String, dynamic> decodedEvents = jsonDecode(eventsJson);
        setState(() {
          _events = decodedEvents.map((key, value) {
            final date = DateTime.parse(key);
            final eventsList = (value as List)
                .map((e) => StudyEvent.fromJson(e as Map<String, dynamic>))
                .toList();
            return MapEntry(date, eventsList);
          });
        });
      }
    } catch (e, stackTrace) {
      print('Error loading events: $e\n$stackTrace');
      if (mounted) _showSnackBar('Failed to load events.', Colors.redAccent);
    }
  }

  Future<void> _saveEvents() async {
    if (_isDisposed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedEvents = jsonEncode(_events.map((key, value) {
        return MapEntry(
            key.toIso8601String(), value.map((e) => e.toJson()).toList());
      }));
      await prefs.setString(_eventsKey, encodedEvents);
    } catch (e, stackTrace) {
      print('Error saving events: $e\n$stackTrace');
      if (mounted) _showSnackBar('Failed to save events.', Colors.redAccent);
    }
  }

  List<StudyEvent> _getEventsForDay(DateTime day) {
    final dayEvents = _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
    if (_selectedEventTypeFilter == null) {
      return dayEvents;
    }
    return dayEvents.where((event) => event.type == _selectedEventTypeFilter).toList();
  }

  void _addEvent(StudyEvent event) async {
    if (_isDisposed) return;
    final eventDateKey = DateTime.utc(event.date.year, event.date.month, event.date.day);
    if (mounted) {
      setState(() {
        _events.putIfAbsent(eventDateKey, () => []).add(event);
        _events[eventDateKey]!.sort((a, b) => a.date.compareTo(b.date));
        _selectedDay = event.date;
        _focusedDay = event.date;
      });
    }
    await _saveEvents();
    await scheduleEventNotification(event);
    if (mounted) _showSnackBar('Event added: ${event.title}', Colors.green);
  }

  void _updateEvent(StudyEvent oldEvent, StudyEvent newEvent) async {
    if (_isDisposed) return;
    final oldEventDateKey = DateTime.utc(oldEvent.date.year, oldEvent.date.month, oldEvent.date.day);
    final newEventDateKey = DateTime.utc(newEvent.date.year, newEvent.date.month, newEvent.date.day);

    if (mounted) {
      setState(() {
        _events[oldEventDateKey]?.removeWhere((e) => e.id == oldEvent.id);
        if (_events[oldEventDateKey]?.isEmpty ?? false) {
          _events.remove(oldEventDateKey);
        }
        _events.putIfAbsent(newEventDateKey, () => []).add(newEvent);
        _events[newEventDateKey]!.sort((a, b) => a.date.compareTo(b.date));
         _selectedDay = newEvent.date;
        _focusedDay = newEvent.date;
      });
    }
    await _saveEvents();
    await scheduleEventNotification(newEvent);
    if (mounted) _showSnackBar('Event updated: ${newEvent.title}', Colors.blueAccent);
  }

  void _deleteEvent(StudyEvent event) async {
    if (_isDisposed) return;
    final eventDateKey = DateTime.utc(event.date.year, event.date.month, event.date.day);
    if (mounted) {
      setState(() {
        _events[eventDateKey]?.removeWhere((e) => e.id == event.id);
        if (_events[eventDateKey]?.isEmpty ?? false) {
          _events.remove(eventDateKey);
        }
      });
    }
    await _saveEvents();
    await flutterLocalNotificationsPlugin.cancel(event.id.hashCode, tag: 'event_notification');
    if (mounted) _showSnackBar('Event deleted: ${event.title}', Colors.redAccent);
  }

  void _toggleCompletion(StudyEvent event) {
    if(_isDisposed) return;
    final updatedEvent = StudyEvent(
        id: event.id,
        title: event.title,
        description: event.description,
        date: event.date,
        type: event.type,
        isCompleted: !event.isCompleted);
    _updateEvent(event, updatedEvent);
  }

  void _showAddEditEventDialog({StudyEvent? eventToEdit}) {
    final bool isEditing = eventToEdit != null;
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);

    String title = eventToEdit?.title ?? '';
    String description = eventToEdit?.description ?? '';
    EventType selectedType = eventToEdit?.type ?? EventType.study;
    DateTime initialDateTime = eventToEdit?.date ?? _selectedDay ?? DateTime.now();
    
    if (!isEditing) {
        final now = DateTime.now();
        if(isSameDay(initialDateTime, now) && initialDateTime.hour < now.hour) {
            initialDateTime = DateTime(now.year, now.month, now.day, now.hour, (now.minute ~/ 15 + 1) * 15);
            if (initialDateTime.minute >= 60) {
                 initialDateTime = initialDateTime.add(const Duration(hours: 1)).copyWith(minute: 0);
            }
        } else if (initialDateTime.hour == 0 && initialDateTime.minute == 0) {
            initialDateTime = DateTime(initialDateTime.year, initialDateTime.month, initialDateTime.day, 9, 0);
        }
    }

    DateTime selectedDate = DateTime(initialDateTime.year, initialDateTime.month, initialDateTime.day);
    TimeOfDay selectedTime = TimeOfDay(hour: initialDateTime.hour, minute: initialDateTime.minute);

    final inputDecoration = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
    );
    final focusedInputDecoration = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.only(
            top: 20,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle with animation
                Center(
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) => Transform.scale(
                      scale: value,
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_calendar_rounded : Icons.add_task_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Schedule' : 'New Schedule',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat.yMMMMEEEEd().format(_selectedDay ?? DateTime.now()),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.error.withOpacity(0.1),
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title field with enhanced styling
                        _buildAnimatedTextField(
                          initialValue: title,
                          labelText: 'Event Title',
                          hintText: 'What are you planning to study?',
                          prefixIcon: Icons.title_rounded,
                          decoration: inputDecoration,
                          focusedDecoration: focusedInputDecoration,
                          onChanged: (value) => title = value,
                          validator: (v) => v!.trim().isEmpty ? 'Title is required' : null,
                          delay: 100,
                        ),
                        const SizedBox(height: 20),
                        // Description field
                        _buildAnimatedTextField(
                          initialValue: description,
                          labelText: 'Description',
                          hintText: 'Add any additional notes...',
                          prefixIcon: Icons.notes_rounded,
                          decoration: inputDecoration,
                          focusedDecoration: focusedInputDecoration,
                          maxLines: 3,
                          minLines: 1,
                          onChanged: (value) => description = value,
                          delay: 200,
                        ),
                        const SizedBox(height: 24),
                        // Event type section with animation
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 400),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) => Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Opacity(
                              opacity: value,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.category_rounded, 
                                        color: theme.colorScheme.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Event Type', 
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        )),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: EventType.values.map((type) {
                                      final color = getEventTypeColor(type, context);
                                      final isSelected = selectedType == type;
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        child: FilterChip(
                                          label: Text(
                                            getEventTypeText(type),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: isSelected 
                                                ? theme.colorScheme.onPrimary 
                                                : color,
                                            ),
                                          ),
                                          avatar: Icon(
                                            getEventTypeIcon(type),
                                            size: 18,
                                            color: isSelected 
                                              ? theme.colorScheme.onPrimary 
                                              : color,
                                          ),
                                          selected: isSelected,
                                          onSelected: (selected) {
                                            setSheetState(() => selectedType = type);
                                          },
                                          selectedColor: color,
                                          checkmarkColor: theme.colorScheme.onPrimary,
                                          backgroundColor: color.withOpacity(0.08),
                                          elevation: isSelected ? 4 : 0,
                                          pressElevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            side: BorderSide(
                                              color: isSelected ? color : color.withOpacity(0.3),
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Date and time section
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 500),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) => Transform.translate(
                            offset: Offset(0, 30 * (1 - value)),
                            child: Opacity(
                              opacity: value,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildDateTimeCard(
                                      icon: Icons.calendar_month_rounded,
                                      label: "Date",
                                      value: DateFormat.yMMMEd().format(selectedDate),
                                      onTap: () async {
                                        final pickedDate = await showDatePicker(
                                          context: context,
                                          initialDate: selectedDate,
                                          firstDate: DateTime(DateTime.now().year - 2),
                                          lastDate: DateTime(DateTime.now().year + 5),
                                          builder: (context, child) => Theme(
                                            data: theme.copyWith(
                                              colorScheme: theme.colorScheme.copyWith(
                                                primary: theme.colorScheme.primary,
                                              ),
                                            ),
                                            child: child!,
                                          ),
                                        );
                                        if (pickedDate != null) {
                                          setSheetState(() => selectedDate = pickedDate);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDateTimeCard(
                                      icon: Icons.access_time_filled_rounded,
                                      label: "Time",
                                      value: selectedTime.format(context),
                                      onTap: () async {
                                        final pickedTime = await showTimePicker(
                                          context: context,
                                          initialTime: selectedTime,
                                          builder: (context, child) => Theme(
                                            data: theme.copyWith(
                                              colorScheme: theme.colorScheme.copyWith(
                                                primary: theme.colorScheme.primary,
                                              ),
                                            ),
                                            child: child!,
                                          ),
                                        );
                                        if (pickedTime != null) {
                                          setSheetState(() => selectedTime = pickedTime);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Save button with animation
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final finalDateTime = DateTime(
                              selectedDate.year, selectedDate.month, selectedDate.day,
                              selectedTime.hour, selectedTime.minute,
                            );

                            if (!isEditing && finalDateTime.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
                              _showSnackBar("Cannot schedule events in the past.", Colors.orangeAccent);
                              return;
                            }

                            final newEvent = StudyEvent(
                              id: eventToEdit?.id,
                              title: title.trim(),
                              description: description.trim().isEmpty ? null : description.trim(),
                              date: finalDateTime,
                              type: selectedType,
                              isCompleted: eventToEdit?.isCompleted ?? false,
                            );
                            Navigator.pop(context);
                            if (isEditing) {
                              _updateEvent(eventToEdit, newEvent);
                            } else {
                              _addEvent(newEvent);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: theme.colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: Icon(isEditing ? Icons.save_alt_rounded : Icons.add_task_rounded),
                        label: Text(
                          isEditing ? 'Save Changes' : 'Add Event',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required String initialValue,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    required OutlineInputBorder decoration,
    required OutlineInputBorder focusedDecoration,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    int maxLines = 1,
    int minLines = 1,
    int delay = 0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - value)),
        child: Opacity(
          opacity: value,
          child: TextFormField(
            initialValue: initialValue,
            decoration: InputDecoration(
              labelText: labelText,
              hintText: hintText,
              prefixIcon: Icon(prefixIcon),
              border: decoration,
              focusedBorder: focusedDecoration,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            ),
            maxLines: maxLines,
            minLines: minLines,
            onChanged: onChanged,
            validator: validator,
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface.withOpacity(0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted || _isDisposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.green 
                ? Icons.check_circle_outline
                : backgroundColor == Colors.redAccent
                  ? Icons.error_outline
                  : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 5, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Study Calendar'),
          ],
        ),
        actions: [
          // Enhanced filter button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _selectedEventTypeFilter != null 
                ? theme.colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: PopupMenuButton<EventType?>(
              icon: Icon(
                Icons.filter_list_rounded,
                color: _selectedEventTypeFilter != null 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.onSurface,
              ),
              tooltip: "Filter by Event Type",
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (EventType? type) {
                if (mounted) {
                  setState(() {
                    _selectedEventTypeFilter = type;
                  });
                }
              },
              itemBuilder: (BuildContext context) {
                List<PopupMenuEntry<EventType?>> items = [];
                items.add(
                  PopupMenuItem<EventType?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.clear_all_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'All Types',
                          style: TextStyle(
                            fontWeight: _selectedEventTypeFilter == null 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                items.add(const PopupMenuDivider());
                for (EventType type in EventType.values) {
                  items.add(
                    CheckedPopupMenuItem<EventType?>(
                      value: type,
                      checked: _selectedEventTypeFilter == type,
                      child: Row(
                        children: [
                          Icon(
                            getEventTypeIcon(type),
                            color: getEventTypeColor(type, context),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(getEventTypeText(type)),
                        ],
                      ),
                    ),
                  );
                }
                return items;
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Go to Today',
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              foregroundColor: theme.colorScheme.primary,
            ),
            onPressed: () {
              if (mounted) {
                setState(() {
                  _focusedDay = DateTime.now();
                  _selectedDay = _focusedDay;
                  _selectedEventTypeFilter = null;
                });
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Enhanced calendar card
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: TableCalendar(
                firstDay: DateTime.utc(DateTime.now().year - 2, 1, 1),
                lastDay: DateTime.utc(DateTime.now().year + 5, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: _getEventsForDay,
                onDaySelected: (selectedDay, focusedDay) {
                  if (mounted && !isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                onFormatChanged: (format) {
                  if (mounted && _calendarFormat != format) {
                    setState(() => _calendarFormat = format);
                  }
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return null;
                    bool hasIncomplete = events.any((e) => e is StudyEvent ? !e.isCompleted : false);
                    return Positioned(
                      right: 6,
                      bottom: 6,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: hasIncomplete 
                              ? [theme.colorScheme.error, theme.colorScheme.error.withOpacity(0.8)]
                              : [Colors.green, Colors.green.withOpacity(0.8)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: hasIncomplete 
                                ? theme.colorScheme.error.withOpacity(0.3)
                                : Colors.green.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${events.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  todayDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.secondary.withOpacity(0.3),
                        theme.colorScheme.secondary.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.secondary,
                      width: 2,
                    ),
                  ),
                  selectedDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.8),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  weekendTextStyle: TextStyle(
                    color: theme.colorScheme.error.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                  cellMargin: const EdgeInsets.all(4),
                  cellPadding: const EdgeInsets.all(8),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                  formatButtonDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.1),
                        theme.colorScheme.primary.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  formatButtonTextStyle: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  titleTextStyle: theme.textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left_rounded,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  headerPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          // Enhanced events section header
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedEventTypeFilter == null
                          ? "Today's Schedule"
                          : "${getEventTypeText(_selectedEventTypeFilter!)} Events",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat.yMMMMd().format(_selectedDay ?? _focusedDay),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_getEventsForDay(_selectedDay ?? _focusedDay).length} events',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildEventsList()),
        ],
      ),
      floatingActionButton: SlideTransition(
        position: _fabSlideAnimation,
        child: ScaleTransition(
          scale: _fabScaleAnimation,
          child: FloatingActionButton.extended(
            onPressed: () => _showAddEditEventDialog(),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            elevation: 8,
            extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
            label: const Text(
              'Schedule Event',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.add_alarm_rounded),
          ),
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    final events = _getEventsForDay(_selectedDay ?? _focusedDay);
    final theme = Theme.of(context);

    if (events.isEmpty) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.event_busy_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _selectedEventTypeFilter == null 
                  ? 'No events scheduled for this day' 
                  : 'No "${getEventTypeText(_selectedEventTypeFilter!)}" events found',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to schedule a new event',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedList(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      initialItemCount: events.length,
      itemBuilder: (context, index, animation) {
        final event = events[index];
        return SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(1, 0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutBack)),
          ),
          child: FadeTransition(
            opacity: animation,
            child: _buildEventCard(event),
          ),
        );
      },
    );
  }

  Widget _buildEventCard(StudyEvent event) {
    final theme = Theme.of(context);
    final color = getEventTypeColor(event.type, context);
    final icon = getEventTypeIcon(event.type);

    return Dismissible(
      key: ValueKey(event.id),
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.error.withOpacity(0.8),
              theme.colorScheme.error,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.delete_sweep_rounded,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 4),
            const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                const Text("Confirm Delete"),
              ],
            ),
            content: Text("Are you sure you want to delete '${event.title}'?"),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                child: const Text("DELETE"),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteEvent(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _showAddEditEventDialog(eventToEdit: event),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Event type icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                // Event details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: event.isCompleted 
                            ? TextDecoration.lineThrough 
                            : null,
                          decorationThickness: 2.0,
                          color: event.isCompleted 
                            ? theme.hintColor 
                            : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_filled_rounded,
                            size: 16,
                            color: color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat.jm().format(event.date),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              getEventTypeText(event.type),
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (event.description != null && event.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          event.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Completion toggle
                Container(
                  decoration: BoxDecoration(
                    color: event.isCompleted 
                      ? Colors.green.withOpacity(0.1)
                      : theme.hintColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        event.isCompleted 
                          ? Icons.check_circle_rounded 
                          : Icons.radio_button_unchecked_rounded,
                        key: ValueKey(event.isCompleted),
                        color: event.isCompleted 
                          ? Colors.green 
                          : theme.hintColor.withOpacity(0.6),
                        size: 28,
                      ),
                    ),
                    tooltip: event.isCompleted 
                      ? 'Mark as Incomplete' 
                      : 'Mark as Complete',
                    onPressed: () => _toggleCompletion(event),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
