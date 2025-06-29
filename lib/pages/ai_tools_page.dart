import 'package:flutter/material.dart';

class AIToolsPage extends StatefulWidget {
  final String text;
  final Function(String, String, {int? questionCount, String? quizType, String? difficulty}) performAiAction;
  final String lectureId;
  final String lectureName;

  const AIToolsPage({
    Key? key,
    required this.text,
    required this.performAiAction,
    required this.lectureId,
    required this.lectureName,
  }) : super(key: key);

  @override
  _AIToolsPageState createState() => _AIToolsPageState();
}

class _AIToolsPageState extends State<AIToolsPage> {
  int questionCount = 10;
  int flashcardCount = 10;
  String selectedQuizType = 'mixed';
  String selectedDifficulty = 'medium'; // Default difficulty

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AI Study Tools', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Generate study materials based on your PDF content',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // Comprehensive Study Guide
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book, 
                        color: Colors.blue,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comprehensive Study Guide',
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Generate all study materials in one organized document',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudyGuidesListPage(
                                lectureId: widget.lectureId,
                                lectureName: widget.lectureName,
                              ),
                            ),
                          );
                          
                          if (result == 'generate' && mounted) {
                            widget.performAiAction(widget.text, 'comprehensive_guide');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history, size: 18, color: Colors.white70),
                                const SizedBox(width: 8),
                                Text(
                                  'View Saved',
                                  style: TextStyle(
                                    color: Colors.grey[200],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          widget.performAiAction(widget.text, 'comprehensive_guide');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: const BorderRadius.only(
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Generate New',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          const Divider(color: Colors.grey),
          const SizedBox(height: 16),
          
          // Flashcards
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.style_outlined, 
                        color: Colors.amber,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Flashcards',
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Create flashcards for studying key concepts',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text('Number of cards:', style: TextStyle(color: Colors.white)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            overlayShape: SliderComponentShape.noOverlay,
                            trackHeight: 4.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                            activeTrackColor: Colors.amber,
                            inactiveTrackColor: Colors.amber.withOpacity(0.2),
                            thumbColor: Colors.amber,
                          ),
                          child: Slider(
                            value: flashcardCount.toDouble(),
                            min: 5,
                            max: 50,
                            divisions: 45,
                            label: flashcardCount.toString(),
                            onChanged: (value) {
                              setState(() {
                                flashcardCount = value.toInt();
                              });
                            },
                          ),
                        ),
                      ),
                      Container(
                        width: 30,
                        alignment: Alignment.center,
                        child: Text(
                          flashcardCount.toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.performAiAction(widget.text, 'flashcards', questionCount: flashcardCount);
                      },
                      child: const Text('Generate Flashcards', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          const Divider(color: Colors.grey),
          const SizedBox(height: 16),
          
          // Quiz Generator
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.quiz_outlined, 
                        color: Colors.green,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quiz Generator',
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Create practice questions based on content',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text('Select quiz type:', style: TextStyle(color: Colors.white)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Wrap(
                    spacing: 8.0,
                    children: [
                      _buildQuizTypeChip('Mixed', 'mixed', selectedQuizType, 
                        () => setState(() => selectedQuizType = 'mixed')
                      ),
                      _buildQuizTypeChip('Long/Short Response', 'long_response', selectedQuizType, 
                        () => setState(() => selectedQuizType = 'long_response')
                      ),
                      _buildQuizTypeChip('True/False', 'true_false', selectedQuizType, 
                        () => setState(() => selectedQuizType = 'true_false')
                      ),
                      _buildQuizTypeChip('Multiple Choice', 'multiple_choice', selectedQuizType, 
                        () => setState(() => selectedQuizType = 'multiple_choice')
                      ),
                      _buildQuizTypeChip('Fill in the Blank', 'fill_blank', selectedQuizType, 
                        () => setState(() => selectedQuizType = 'fill_blank')
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text('Select difficulty:', style: TextStyle(color: Colors.white)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Wrap(
                    spacing: 8.0,
                    children: [
                      _buildDifficultyChip('Easy', 'easy', selectedDifficulty, 
                        () => setState(() => selectedDifficulty = 'easy')
                      ),
                      _buildDifficultyChip('Medium', 'medium', selectedDifficulty, 
                        () => setState(() => selectedDifficulty = 'medium')
                      ),
                      _buildDifficultyChip('Hard', 'hard', selectedDifficulty, 
                        () => setState(() => selectedDifficulty = 'hard')
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      const Text('Number of questions:', style: TextStyle(color: Colors.white)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            overlayShape: SliderComponentShape.noOverlay,
                            trackHeight: 4.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                            activeTrackColor: Colors.green,
                            inactiveTrackColor: Colors.green.withOpacity(0.2),
                            thumbColor: Colors.green,
                          ),
                          child: Slider(
                            value: questionCount.toDouble(),
                            min: 5,
                            max: 50,
                            divisions: 45,
                            label: questionCount.toString(),
                            onChanged: (value) {
                              setState(() {
                                questionCount = value.toInt();
                              });
                            },
                          ),
                        ),
                      ),
                      Container(
                        width: 30,
                        alignment: Alignment.center,
                        child: Text(
                          questionCount.toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.performAiAction(widget.text, 'questions', 
                          questionCount: questionCount,
                          quizType: selectedQuizType,
                          difficulty: selectedDifficulty
                        );
                      },
                      child: const Text('Generate Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildQuizTypeChip(String label, String value, String selectedValue, VoidCallback onTap) {
    final isSelected = value == selectedValue;
    return ChoiceChip(
      label: Text(label, style: TextStyle(
        color: isSelected ? Colors.blue : Colors.white,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      )),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) onTap();
      },
      backgroundColor: Colors.grey[800],
      selectedColor: Colors.blue.withOpacity(0.2),
    );
  }
  
  Widget _buildDifficultyChip(String label, String value, String selectedValue, VoidCallback onTap) {
    final isSelected = value == selectedValue;
    Color chipColor;
    
    switch (value) {
      case 'easy':
        chipColor = Colors.green;
        break;
      case 'hard':
        chipColor = Colors.red;
        break;
      case 'medium':
      default:
        chipColor = Colors.orange;
        break;
    }
    
    return ChoiceChip(
      label: Text(label, style: TextStyle(
        color: isSelected ? chipColor : Colors.white,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      )),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) onTap();
      },
      backgroundColor: Colors.grey[800],
      selectedColor: chipColor.withOpacity(0.2),
    );
  }
}

// This is a placeholder - you'll need to use your actual StudyGuidesListPage
class StudyGuidesListPage extends StatelessWidget {
  final String lectureId;
  final String lectureName;

  const StudyGuidesListPage({
    Key? key,
    required this.lectureId,
    required this.lectureName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Study Guides for $lectureName', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No saved study guides yet',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, 'generate');
              },
              child: const Text('Generate New Study Guide'),
            ),
          ],
        ),
      ),
    );
  }
}
