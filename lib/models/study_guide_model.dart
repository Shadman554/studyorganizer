// lib/models/study_guide_model.dart

class StudyGuide {
  final String id;
  final String title;
  final String lectureId;
  final String lectureName;
  final DateTime createdAt;
  final Map<String, String> content;

  StudyGuide({
    required this.id,
    required this.title,
    required this.lectureId,
    required this.lectureName,
    required this.createdAt,
    required this.content,
  });

  // Create from JSON
  factory StudyGuide.fromJson(Map<String, dynamic> json) {
    return StudyGuide(
      id: json['id'] as String,
      title: json['title'] as String,
      lectureId: json['lectureId'] as String,
      lectureName: json['lectureName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      content: Map<String, String>.from(json['content'] as Map),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'lectureId': lectureId,
      'lectureName': lectureName,
      'createdAt': createdAt.toIso8601String(),
      'content': content,
    };
  }
}
