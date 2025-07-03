
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
  String selectedDifficulty = 'medium';
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Study Tools'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.1),
                    Theme.of(context).primaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 48,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AI Study Assistant',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate personalized study materials from your lecture content',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Study Guide Card
            _buildSimpleCard(
              context,
              title: 'Complete Study Guide',
              subtitle: 'Get a comprehensive summary with key topics and terms',
              icon: Icons.menu_book_outlined,
              color: Colors.blue,
              onTap: () => _generateWithLoading('comprehensive_guide'),
              hasSubOptions: false,
            ),
            
            const SizedBox(height: 16),
            
            // Flashcards Card
            _buildSimpleCard(
              context,
              title: 'Flashcards',
              subtitle: 'Create interactive cards for quick review',
              icon: Icons.style_outlined,
              color: Colors.orange,
              onTap: () => _showFlashcardOptions(),
              hasSubOptions: true,
            ),
            
            const SizedBox(height: 16),
            
            // Quiz Card
            _buildSimpleCard(
              context,
              title: 'Practice Quiz',
              subtitle: 'Test your knowledge with custom questions',
              icon: Icons.quiz_outlined,
              color: Colors.green,
              onTap: () => _showQuizOptions(),
              hasSubOptions: true,
            ),
            
            const SizedBox(height: 24),
            
            if (_isGenerating)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Generating your study materials...',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool hasSubOptions,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                hasSubOptions ? Icons.tune : Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: hasSubOptions ? 24 : 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFlashcardOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.style_outlined, color: Colors.orange),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Flashcard Options',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Number of Cards',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Slider(
                  value: flashcardCount.toDouble(),
                  min: 5,
                  max: 25,
                  divisions: 20,
                  label: '$flashcardCount cards',
                  onChanged: (value) {
                    setState(() {
                      flashcardCount = value.toInt();
                    });
                  },
                ),
                Text(
                  '$flashcardCount cards',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _generateWithLoading('flashcards', count: flashcardCount);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Generate Flashcards',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

  void _showQuizOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.quiz_outlined, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Quiz Options',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Question Count
                Text(
                  'Number of Questions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Slider(
                  value: questionCount.toDouble(),
                  min: 5,
                  max: 20,
                  divisions: 15,
                  label: '$questionCount questions',
                  onChanged: (value) {
                    setState(() {
                      questionCount = value.toInt();
                    });
                  },
                ),
                Text(
                  '$questionCount questions',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Difficulty
                Text(
                  'Difficulty Level',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildDifficultyChip('Easy', 'easy', setState),
                    const SizedBox(width: 8),
                    _buildDifficultyChip('Medium', 'medium', setState),
                    const SizedBox(width: 8),
                    _buildDifficultyChip('Hard', 'hard', setState),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Question Type
                Text(
                  'Question Type',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuizTypeChip('Mixed', 'mixed', setState),
                    _buildQuizTypeChip('Multiple Choice', 'multiple_choice', setState),
                    _buildQuizTypeChip('True/False', 'true_false', setState),
                    _buildQuizTypeChip('Short Answer', 'long_response', setState),
                  ],
                ),
                
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _generateWithLoading('questions');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Generate Quiz',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

  Widget _buildDifficultyChip(String label, String value, StateSetter setState) {
    final isSelected = selectedDifficulty == value;
    Color chipColor = value == 'easy' ? Colors.green : 
                     value == 'hard' ? Colors.red : Colors.orange;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedDifficulty = value;
        });
      },
      selectedColor: chipColor.withOpacity(0.2),
      checkmarkColor: chipColor,
      labelStyle: TextStyle(
        color: isSelected ? chipColor : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildQuizTypeChip(String label, String value, StateSetter setState) {
    final isSelected = selectedQuizType == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedQuizType = value;
        });
      },
      selectedColor: Colors.green.withOpacity(0.2),
      checkmarkColor: Colors.green,
      labelStyle: TextStyle(
        color: isSelected ? Colors.green : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _generateWithLoading(String action, {int? count}) async {
    setState(() {
      _isGenerating = true;
    });

    try {
      Navigator.pop(context);
      if (action == 'flashcards') {
        widget.performAiAction(widget.text, action, questionCount: count ?? flashcardCount);
      } else if (action == 'questions') {
        widget.performAiAction(
          widget.text, 
          action,
          questionCount: questionCount,
          quizType: selectedQuizType,
          difficulty: selectedDifficulty,
        );
      } else {
        widget.performAiAction(widget.text, action);
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }
}

// Simplified placeholder for study guides
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
      appBar: AppBar(
        title: Text('Study Guides'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No saved study guides yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, 'generate');
              },
              icon: const Icon(Icons.add),
              label: const Text('Generate New Study Guide'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
