class Flashcard {
  final String id;
  final String question;
  final String answer;
  final String category;
  final bool isLearned;
  final DateTime createdAt;
  final DateTime? lastReviewed;

  Flashcard({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    this.isLearned = false,
    required this.createdAt,
    this.lastReviewed,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      category: json['category'] as String,
      isLearned: json['isLearned'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastReviewed: json['lastReviewed'] != null 
          ? DateTime.parse(json['lastReviewed'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'category': category,
      'isLearned': isLearned,
      'createdAt': createdAt.toIso8601String(),
      'lastReviewed': lastReviewed?.toIso8601String(),
    };
  }
} 