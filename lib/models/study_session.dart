class StudySession {
  final String id;
  final DateTime date;
  final double duration; // in minutes
  final String? subject;
  final String? notes;

  StudySession({
    required this.id,
    required this.date,
    required this.duration,
    this.subject,
    this.notes,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      duration: (json['duration'] as num).toDouble(),
      subject: json['subject'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'duration': duration,
      'subject': subject,
      'notes': notes,
    };
  }
} 