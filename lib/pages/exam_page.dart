// lib/pages/exam_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart'; // Adjust path if needed

class ExamPage extends StatefulWidget {
  final List<String> questions;
  final String pdfText;
  final AiService aiService;
  final String quizType;

  const ExamPage({
    super.key,
    required this.questions,
    required this.pdfText,
    required this.aiService,
    this.quizType = 'mixed',
  });

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  int _currentQuestionIndex = 0;
  final _answerController = TextEditingController();
  String? _feedback;
  bool _isLoading = false;
  bool _answered = false;
  String? _correctAnswer; // Store the correct answer for multiple choice
  
  // Track quiz results
  final List<bool> _questionResults = [];
  final List<String> _userAnswers = [];
  final List<String?> _correctAnswers = [];

  void _checkAnswer() async {
    if (_answerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an answer.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _feedback = null;
      _answered = false;
    });

    // For multiple choice with a known correct answer, provide immediate feedback
    if (widget.quizType == 'multiple_choice' && _correctAnswer != null) {
      // The _answerController.text for multiple choice will hold the selected option letter (e.g., 'A')
      final userAnswerLetter = _answerController.text.trim();
      final isCorrect = userAnswerLetter == _correctAnswer;
      
      if (isCorrect) {
        _feedback = 'Correct! Your answer "$userAnswerLetter" is the right choice.';
      } else {
        _feedback = 'Incorrect. The correct answer is $_correctAnswer.';
      }
      
      // Store the result
      _questionResults.add(isCorrect);
      _userAnswers.add(userAnswerLetter);
      _correctAnswers.add(_correctAnswer);
      
      setState(() {
        _isLoading = false;
        _answered = true;
      });
      return;
    }

    // For other question types, use the AI to check the answer
    _feedback = await widget.aiService.checkAnswer(
      widget.pdfText,
      widget.questions[_currentQuestionIndex],
      _answerController.text,
    );

    // Determine if the answer is correct based on the feedback
    final isCorrect = _feedback?.toLowerCase().startsWith('correct') ?? false;
    
    // Store the result
    _questionResults.add(isCorrect);
    _userAnswers.add(_answerController.text);
    _correctAnswers.add(null); // We don't have the exact correct answer for non-multiple choice

    setState(() {
      _isLoading = false;
      _answered = true;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _answerController.clear();
        _feedback = null;
        _answered = false;
        _correctAnswer = null; // Reset correct answer for next question
      });
    } else {
      // Show results page instead of just popping back
      _showQuizResults();
    }
  }
  
  void _showQuizResults() {
    // Calculate statistics
    final int totalQuestions = widget.questions.length;
    final int correctAnswers = _questionResults.where((result) => result).length;
    final double percentage = totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0;
    
    // Get theme colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final cardColor = isDark ? Color(0xFF121212) : Theme.of(context).colorScheme.surface;
    final highlightColor = Colors.blue; // As per user preference
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: isDark ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: highlightColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: highlightColor,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quiz Results',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: highlightColor,
                          ),
                        ),
                        Text(
                          'You completed ${widget.questions.length} questions',
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Score summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: highlightColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildResultStat('Score', '$correctAnswers/$totalQuestions', highlightColor, textColor),
                        _buildResultStat('Percentage', '${percentage.toStringAsFixed(1)}%', highlightColor, textColor),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: highlightColor.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(percentage)),
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getScoreMessage(percentage),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(percentage),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Return to previous screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        _showDetailedResults();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: highlightColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('View Details'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildResultStat(String label, String value, Color highlightColor, Color textColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: textColor.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: highlightColor,
          ),
        ),
      ],
    );
  }
  
  Color _getScoreColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.blue;
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }
  
  String _getScoreMessage(double percentage) {
    if (percentage >= 90) return 'Excellent!'; 
    if (percentage >= 80) return 'Great job!'; 
    if (percentage >= 70) return 'Good work!'; 
    if (percentage >= 60) return 'Not bad!'; 
    if (percentage >= 40) return 'Keep practicing!'; 
    return 'More study needed';
  }
  
  void _copyAllQuestionsAndAnswers() {
    // Build a formatted string with all questions and answers
    final StringBuffer buffer = StringBuffer();
    
    buffer.writeln('EXAM QUESTIONS AND ANSWERS');
    buffer.writeln('==========================');
    buffer.writeln();
    
    buffer.writeln('Quiz Type: ${_getQuizTypeLabel()}');
    buffer.writeln();
    
    // Add all questions and correct answers only
    for (int i = 0; i < widget.questions.length; i++) {
      String question = widget.questions[i];
      // Clean up the question text
      question = question.replaceFirst('Q: ', '');
      
      // For multiple choice, extract just the question part and options
      if (question.contains('A)')) {
        final parts = question.split('A)');
        if (parts.isNotEmpty) {
          final questionText = parts[0].trim();
          // Add options back in a cleaner format
          final optionsText = 'A)${parts[1]}';
          final optionMatches = RegExp(r'([A-D]\)\s*(.*?)(?=\s*[A-D]\)|CORRECT:|$))', dotAll: true);
          final matches = optionMatches.allMatches(optionsText);
          
          buffer.writeln('Q${i + 1}: $questionText');
          buffer.writeln();
          
          // Add options
          for (final match in matches) {
            if (match.group(0) != null) {
              buffer.writeln('  ${match.group(0)!.trim()}');
            }
          }
        } else {
          buffer.writeln('Q${i + 1}: $question');
        }
      } else {
        buffer.writeln('Q${i + 1}: $question');
      }
      
      buffer.writeln();
      
      // Add correct answer if available
      if (i < _correctAnswers.length && _correctAnswers[i] != null) {
        buffer.writeln('Correct Answer: ${_correctAnswers[i]}');
      } else if (widget.quizType == 'multiple_choice' || question.contains('A)')) {
        // For multiple choice questions without explicit correct answer, try to extract from question
        final correctMatch = RegExp(r'CORRECT:\s*([A-D])').firstMatch(question);
        if (correctMatch != null && correctMatch.group(1) != null) {
          buffer.writeln('Correct Answer: ${correctMatch.group(1)}');
        }
      }
      
      buffer.writeln();
      buffer.writeln('-------------------');
      buffer.writeln();
    }
    
    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('Questions and correct answers copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  
  void _showDetailedResults() {
    // Get theme colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final cardColor = isDark ? Color(0xFF121212) : Theme.of(context).colorScheme.surface;
    final highlightColor = Colors.blue; // As per user preference
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detailed Results',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: highlightColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Question by question breakdown',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              
              // List of questions with results
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.questions.length,
                  itemBuilder: (context, index) {
                    final question = widget.questions[index];
                    final isCorrect = index < _questionResults.length ? _questionResults[index] : false;
                    final userAnswer = index < _userAnswers.length ? _userAnswers[index] : 'Not answered';
                    
                    // Clean up the question text
                    String questionText = question.replaceFirst('Q: ', '');
                    // For multiple choice, extract just the question part
                    if (questionText.contains('A)')) {
                      questionText = questionText.split('A)')[0].trim();
                    }
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCorrect ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Q${index + 1}',
                                  style: TextStyle(
                                    color: isCorrect ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isCorrect ? Icons.check_circle : Icons.cancel,
                                color: isCorrect ? Colors.green : Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCorrect ? 'Correct' : 'Incorrect',
                                style: TextStyle(
                                  color: isCorrect ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            questionText,
                            style: TextStyle(
                              fontSize: 16,
                              color: textColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Your answer: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColor.withOpacity(0.7),
                                ),
                              ),
                              Text(
                                userAnswer,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          if (_correctAnswers[index] != null) ...[  
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Correct answer: ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                ),
                                Text(
                                  _correctAnswers[index]!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              // Copy All Questions & Answers Button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: _copyAllQuestionsAndAnswers,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Questions & Correct Answers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // Return to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: highlightColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getQuizTypeLabel() {
    switch (widget.quizType) {
      case 'long_response':
        return 'Long/Short Response';
      case 'true_false':
        return 'True/False';
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'fill_blank':
        return 'Fill in the Blank';
      case 'mixed':
      default:
        return 'Mixed Questions';
    }
  }
  
  IconData _getQuizTypeIcon() {
    switch (widget.quizType) {
      case 'long_response':
        return Icons.text_fields;
      case 'true_false':
        return Icons.check_circle_outline;
      case 'multiple_choice':
        return Icons.radio_button_checked;
      case 'fill_blank':
        return Icons.text_format;
      case 'mixed':
      default:
        return Icons.quiz;
    }
  }
  
  // Enhanced multiple choice options with improved styling
  List<Widget> _buildMultipleChoiceOptions(List<String> options) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlightColor = Colors.blue; // As per user preference
    final textColor = isDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    
    return [
      ...options.map((option) {
        // Extract the option letter (e.g., "A") and the text (e.g., "Berlin")
        String optionLetter = '';
        String optionDisplayText = option; // Default to full option if parsing fails

        final match = RegExp(r'^([A-D])\)\s*(.*)').firstMatch(option.trim());
        if (match != null && match.groupCount >= 2) {
          optionLetter = match.group(1)!;
          optionDisplayText = match.group(2)!;
        }
        
        final isSelected = _answerController.text == optionLetter;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? highlightColor.withOpacity(isDark ? 0.2 : 0.1)
                : (isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? highlightColor 
                  : highlightColor.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: RadioListTile<String>(
            title: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? highlightColor 
                        : highlightColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      optionLetter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : highlightColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    optionDisplayText,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            value: optionLetter,
            groupValue: _answerController.text.isEmpty ? null : _answerController.text,
            onChanged: _answered ? null : (value) {
              setState(() {
                _answerController.text = value ?? '';
              });
            },
            activeColor: highlightColor,
            controlAffinity: ListTileControlAffinity.trailing,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          ),
        );
      }).toList(),
    ];
  }
  
  List<Widget> _buildTrueFalseOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlightColor = Colors.blue; // As per user preference
    final textColor = isDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    
    return [
      Row(
        children: [
          Expanded(
            child: _buildTrueFalseOption('True', highlightColor, isDark, textColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTrueFalseOption('False', highlightColor, isDark, textColor),
          ),
        ],
      ),
    ];
  }
  
  Widget _buildTrueFalseOption(String value, Color highlightColor, bool isDark, Color textColor) {
    final isSelected = _answerController.text == value;
    
    return GestureDetector(
      onTap: _answered ? null : () {
        setState(() {
          _answerController.text = value;
        });
      },
      child: Container(
        height: 60,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? highlightColor.withOpacity(isDark ? 0.2 : 0.1)
              : (isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? highlightColor 
                : highlightColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? highlightColor : highlightColor.withOpacity(0.5),
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.questions[_currentQuestionIndex];
    final cleanQuestion = currentQuestion.replaceFirst('Q: ', '');
    
    // Get theme colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final backgroundColor = isDark ? Colors.black : colorScheme.background;
    final cardColor = isDark ? Color(0xFF121212) : colorScheme.surface;
    final textColor = isDark ? Colors.white : colorScheme.onSurface;
    final highlightColor = Colors.blue; // As per user preference
    
    bool isMultipleChoice = widget.quizType == 'multiple_choice';
    bool isTrueFalse = widget.quizType == 'true_false';
    bool isFillBlank = widget.quizType == 'fill_blank';
    
    if (widget.quizType == 'mixed') {
      // Look for multiple lines starting with A), B), C), D) for multi-choice detection
      isMultipleChoice = currentQuestion.contains(RegExp(r'\n[A-D]\)'));
      isTrueFalse = cleanQuestion.toLowerCase().contains('true or false') || 
                    cleanQuestion.toLowerCase().contains('true/false');
    }
    
    String questionText = cleanQuestion;
    List<String> options = [];
    
    if (isMultipleChoice) {
      final lines = currentQuestion.split('\n');
      
      int firstOptionLineIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('A)') || line.startsWith('B)') || 
            line.startsWith('C)') || line.startsWith('D)')) {
          firstOptionLineIndex = i;
          break;
        }
      }

      if (firstOptionLineIndex != -1) {
        // Question text is everything before the first option line
        questionText = lines.sublist(0, firstOptionLineIndex).join('\n').replaceFirst('Q: ', '').trim();
        
        // Options are all subsequent lines that start with A), B), C), D)
        for (int i = firstOptionLineIndex; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('A)') || line.startsWith('B)') || 
              line.startsWith('C)') || line.startsWith('D)')) {
            options.add(line); // Add the full line as an option (e.g., "A) Option A text")
          } else if (line.startsWith('CORRECT:')) {
            _correctAnswer = line.replaceFirst('CORRECT:', '').trim();
          }
        }
      } else {
        // Fallback for single-line multiple choice parsing if no newlines are found
        final parts = cleanQuestion.split(RegExp(r'\s*A\)'));
        if (parts.length > 1) {
          questionText = parts[0].trim();
          final optionsText = 'A)${parts[1]}';
          
          final optionMatches = RegExp(r'([A-D]\)\s*(.*?)(?=\s*[A-D]\)|$))', dotAll: true);
          final matches = optionMatches.allMatches(optionsText);
          options = matches.map((m) => m.group(0)?.trim() ?? '').where((s) => s.isNotEmpty).toList();

          final correctMatch = RegExp(r'CORRECT:\s*([A-D])').firstMatch(optionsText);
          if (correctMatch != null) {
            _correctAnswer = correctMatch.group(1)?.trim();
          }
        }
      }
      
      if (options.isEmpty) {
        print('Failed to parse multiple choice options from: $currentQuestion');
        isMultipleChoice = false; // Fallback to text input if options can't be parsed
      }
    }
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Color(0xFF0A0A0A) : primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Question ${_currentQuestionIndex + 1} of ${widget.questions.length}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF121212)],
          ) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            children: [
              // Quiz type indicator with enhanced styling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? highlightColor.withOpacity(0.15) : highlightColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: highlightColor.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getQuizTypeIcon(),
                      color: highlightColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getQuizTypeLabel(),
                      style: TextStyle(
                        color: highlightColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Question card with enhanced styling
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ] : [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question number
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: highlightColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Question ${_currentQuestionIndex + 1}',
                        style: TextStyle(
                          color: highlightColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Question text with enhanced styling
                    Text(
                      questionText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Different input types based on question type with enhanced styling
                    if (isMultipleChoice) ..._buildMultipleChoiceOptions(options)
                    else if (isTrueFalse) ..._buildTrueFalseOptions()
                    else if (isFillBlank) TextField(
                      controller: _answerController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Fill in the Blank',
                        labelStyle: TextStyle(color: highlightColor),
                        hintText: 'Type the missing word or phrase...',
                        hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: highlightColor.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: highlightColor),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      enabled: !_answered, // Disable if answered
                    )
                    else TextField(
                      controller: _answerController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Your Answer',
                        labelStyle: TextStyle(color: highlightColor),
                        hintText: 'Type your answer here...',
                        hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: highlightColor.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: highlightColor),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 4,
                      enabled: !_answered, // Disable if answered
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Action buttons with enhanced styling
              ElevatedButton(
                onPressed: _isLoading || _answered ? null : _checkAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: highlightColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  shadowColor: highlightColor.withOpacity(0.4),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text('Check My Answer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
              
              if (_feedback != null) ...[
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      )
                    ] : [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            (_feedback?.toLowerCase().startsWith('correct') ?? false)
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color: (_feedback?.toLowerCase().startsWith('correct') ?? false)
                                ? Colors.green[400]
                                : Colors.red[400],
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Feedback',
                            style: TextStyle(
                              color: highlightColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const Divider(
                        height: 24,
                        thickness: 1,
                        color: Colors.blue,
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (_feedback?.toLowerCase().startsWith('correct') ?? false)
                              ? Colors.green.withOpacity(isDark ? 0.1 : 0.05)
                              : Colors.red.withOpacity(isDark ? 0.1 : 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_feedback?.toLowerCase().startsWith('correct') ?? false)
                                ? Colors.green.withOpacity(0.3)
                                : Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              (_feedback?.toLowerCase().startsWith('correct') ?? false)
                                  ? Icons.check_circle_outline
                                  : Icons.highlight_off_outlined,
                              color: (_feedback?.toLowerCase().startsWith('correct') ?? false)
                                  ? Colors.green[400]
                                  : Colors.red[400],
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _feedback!,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _nextQuestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            shadowColor: Colors.blue.withOpacity(0.4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentQuestionIndex < widget.questions.length - 1
                                    ? 'Next Question'
                                    : 'Finish Quiz',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                _currentQuestionIndex < widget.questions.length - 1
                                    ? Icons.arrow_forward
                                    : Icons.check_circle,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20), // Add padding at the bottom
            ],
          ),
        ),
      ),
    );
  }
}