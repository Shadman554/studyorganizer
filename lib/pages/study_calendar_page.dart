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

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
    _filterChipAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _filterChipAnimationController.dispose();
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
        _selectedDay = event.date; // Focus on the day of the newly added event
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
         _selectedDay = newEvent.date; // Focus on the day of the updated event
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
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
    );
    final focusedInputDecoration = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: MediaQuery.of(context).viewInsets, // Handles keyboard overlap
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            decoration: BoxDecoration(
              color: theme.dialogTheme.backgroundColor ?? theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center( // Drag handle
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: theme.hintColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Schedule' : 'New Schedule',
                        style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                        tooltip: "Close",
                      ),
                    ],
                  ),
                  const Divider(height: 24, thickness: 0.5),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            initialValue: title,
                            decoration: InputDecoration(
                              labelText: 'Title *', prefixIcon: const Icon(Icons.title_rounded),
                              border: inputDecoration, focusedBorder: focusedInputDecoration,
                            ),
                            onChanged: (value) => title = value,
                            validator: (v) => v!.trim().isEmpty ? 'Title is required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: description,
                            decoration: InputDecoration(
                              labelText: 'Description (Optional)', prefixIcon: const Icon(Icons.notes_rounded),
                              border: inputDecoration, focusedBorder: focusedInputDecoration,
                            ),
                            maxLines: 3, minLines: 1,
                            onChanged: (value) => description = value,
                          ),
                          const SizedBox(height: 20),
                          Text('Event Type *', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: EventType.values.map((type) {
                              final color = getEventTypeColor(type, context);
                              final isSelected = selectedType == type;
                              return FilterChip( // Using FilterChip for a slightly different feel
                                label: Text(getEventTypeText(type), style: TextStyle(fontWeight: FontWeight.w500, color: isSelected ? theme.colorScheme.onPrimary : color)),
                                avatar: Icon(getEventTypeIcon(type), size: 18, color: isSelected ? theme.colorScheme.onPrimary : color),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setSheetState(() => selectedType = type);
                                },
                                selectedColor: color,
                                checkmarkColor: theme.colorScheme.onPrimary,
                                backgroundColor: color.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: isSelected ? color : color.withOpacity(0.3), width: 1.5)
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final pickedDate = await showDatePicker(
                                      context: context, initialDate: selectedDate,
                                      firstDate: DateTime(DateTime.now().year - 2), lastDate: DateTime(DateTime.now().year + 5),
                                      builder: (context, child) => Theme(data: theme, child: child!)
                                    );
                                    if (pickedDate != null) {
                                      setSheetState(() => selectedDate = pickedDate);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: "Date *",
                                      prefixIcon: Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary),
                                      border: inputDecoration, focusedBorder: focusedInputDecoration,
                                    ),
                                    child: Text(DateFormat.yMMMEd().format(selectedDate), style: theme.textTheme.titleSmall),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final pickedTime = await showTimePicker(context: context, initialTime: selectedTime,
                                     builder: (context, child) => Theme(data: theme, child: child!)
                                    );
                                    if (pickedTime != null) {
                                      setSheetState(() => selectedTime = pickedTime);
                                    }
                                  },
                                  child: InputDecorator(
                                     decoration: InputDecoration(
                                      labelText: "Time *",
                                      prefixIcon: Icon(Icons.access_time_filled_rounded, color: theme.colorScheme.primary),
                                      border: inputDecoration, focusedBorder: focusedInputDecoration,
                                    ),
                                    child: Text(selectedTime.format(context), style: theme.textTheme.titleSmall),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
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
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    icon: Icon(isEditing ? Icons.save_alt_rounded : Icons.add_task_rounded),
                    label: Text(isEditing ? 'Save Changes' : 'Add Event', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted || _isDisposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Calendar 🗓️'),
        actions: [
           // Filter button
          PopupMenuButton<EventType?>(
            icon: Icon(Icons.filter_list_rounded, color: _selectedEventTypeFilter != null ? theme.colorScheme.primary : null),
            tooltip: "Filter by Event Type",
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
                  child: Text('All Types', style: TextStyle(fontWeight: _selectedEventTypeFilter == null ? FontWeight.bold : FontWeight.normal)),
                ),
              );
              items.add(const PopupMenuDivider());
              for (EventType type in EventType.values) {
                items.add(
                  CheckedPopupMenuItem<EventType?>(
                    value: type,
                    checked: _selectedEventTypeFilter == type,
                    child: Text(getEventTypeText(type)),
                  ),
                );
              }
              return items;
            },
          ),
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Go to Today',
            onPressed: () {
              if (mounted) {
                setState(() {
                  _focusedDay = DateTime.now();
                  _selectedDay = _focusedDay;
                  _selectedEventTypeFilter = null; // Clear filter when going to today
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 12), // Adjusted top margin
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
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
                    _filterChipAnimationController.forward(from:0);
                  }
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return null;
                    bool hasIncomplete = events.any((e) => e is StudyEvent ? !e.isCompleted : false);
                    return Positioned(
                      right: 5, bottom: 5,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: EdgeInsets.all(events.length > 9 ? 2.5 : 3.5),
                        decoration: BoxDecoration(
                          color: hasIncomplete ? theme.colorScheme.error : Colors.green,
                          shape: BoxShape.circle,
                           boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0,1))]
                        ),
                        child: Text('${events.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  todayDecoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.secondary, width: 1.5)),
                  todayTextStyle: TextStyle(
                      color: theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold),
                  selectedDecoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(
                      color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  weekendTextStyle: TextStyle(color: theme.colorScheme.error.withOpacity(0.7)),
                  tablePadding: const EdgeInsets.only(bottom: 4),
                  cellMargin: const EdgeInsets.all(5.0), // Added margin between cells
                  cellAlignment: Alignment.center,
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                  formatButtonDecoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20), // More rounded
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3))),
                  formatButtonTextStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w500, fontSize: 13),
                  titleTextStyle: theme.textTheme.titleLarge!.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                  leftChevronIcon: Icon(Icons.chevron_left_rounded, color: theme.colorScheme.primary, size: 30),
                  rightChevronIcon: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary, size: 30),
                  headerPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(
                   _selectedEventTypeFilter == null
                       ? "Events for Today"
                       : "${getEventTypeText(_selectedEventTypeFilter!)} Events",
                   style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                 Text(DateFormat.yMMMMd().format(_selectedDay ?? _focusedDay), style: theme.textTheme.titleSmall?.copyWith(color: theme.hintColor)),
              ],
            )
          ),
          const Divider(indent: 16, endIndent: 16, height: 1, thickness: 0.5),
          Expanded(child: _buildEventsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditEventDialog(),
        label: const Text('Schedule Event'),
        icon: const Icon(Icons.add_alarm_rounded),
        tooltip: "Schedule New Study Event",
      ),
    );
  }

  Widget _buildEventsList() {
    final events = _getEventsForDay(_selectedDay ?? _focusedDay);
    final theme = Theme.of(context);

    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy_outlined, size: 72, color: theme.hintColor.withOpacity(0.4)),
              const SizedBox(height: 20),
              Text(
                _selectedEventTypeFilter == null ? 'No events scheduled for this day.' : 'No "${getEventTypeText(_selectedEventTypeFilter!)}" events found.',
                 style: theme.textTheme.titleLarge?.copyWith(color: theme.hintColor)),
              const SizedBox(height: 8),
              Text(
                'Tap "+" to schedule a new event.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor.withOpacity(0.8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final color = getEventTypeColor(event.type, context);
        final icon = getEventTypeIcon(event.type);

        return Dismissible(
          key: ValueKey(event.id),
          background: Container(
            decoration: BoxDecoration(color: theme.colorScheme.error.withOpacity(0.7), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 30),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text("Confirm Delete"),
                content: Text("Are you sure you want to delete '${event.title}'?"),
                actions: <Widget>[
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text("DELETE", style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold))),
                ],
              ),
            );
          },
          onDismissed: (direction) => _deleteEvent(event),
          child: Card(
            elevation: 2.5,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: color.withOpacity(0.5), width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell( // Make the whole card tappable for edit
              onTap: () => _showAddEditEventDialog(eventToEdit: event),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                              decorationThickness: 2.0,
                              decorationColor: theme.hintColor.withOpacity(0.7),
                              color: event.isCompleted ? theme.hintColor : theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat.jm().format(event.date),
                            style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
                          ),
                          if (event.description != null && event.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              event.description!,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                            ),
                          ]
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        event.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: event.isCompleted ? Colors.greenAccent[700] : theme.hintColor.withOpacity(0.6),
                        size: 28,
                      ),
                      tooltip: event.isCompleted ? 'Mark as Incomplete' : 'Mark as Complete',
                      onPressed: () => _toggleCompletion(event),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}