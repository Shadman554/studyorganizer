import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'ai_tools_page.dart';
import 'study_guide_page.dart';
import 'exam_page.dart';
import 'flashcards_page.dart';
import '../services/ai_service.dart' as ai_service;
import '../services/study_guide_service.dart';
import '../models/study_guide_model.dart';

class LectureDetailPage extends StatefulWidget {
  final Lecture lecture;
  final Function(String, PDFLecture) onAddTheory;
  final Function(String, PDFLecture) onAddPractical;
  final Function(String, PDFLecture) onUpdateTheory;
  final Function(String, PDFLecture) onUpdatePractical;
  final Function(String, String) onDeleteTheory;
  final Function(String, String) onDeletePractical;

  const LectureDetailPage({
    super.key,
    required this.lecture,
    required this.onAddTheory,
    required this.onAddPractical,
    required this.onUpdateTheory,
    required this.onUpdatePractical,
    required this.onDeleteTheory,
    required this.onDeletePractical,
  });

  @override
  State<LectureDetailPage> createState() => _LectureDetailPageState();
}

class _LectureDetailPageState extends State<LectureDetailPage> {
  ThemeData get theme => Theme.of(context);
  // --- ADDED FOR AI FEATURES ---
  late final ai_service.AiService _aiService;
  String? _currentPdfText; // To store extracted text for the currently selected PDF
  String? _currentPdfPath; // To track which PDF's text is cached
  bool _isProcessingAi = false; // To show loading indicators for AI tasks
  // --- END ADDED ---

  @override
  void initState() {
    super.initState();
    _aiService = ai_service.AiService(apiKey: 'AIzaSyAiO8RVja7tRdsWMI0RjKDeB8zAt9bGWHk');
    // --- END ADDED ---
  }

  Future<void> _pickAndSavePDF(bool isTheory) async {
    try {
      // Check permissions first
      if (Platform.isAndroid) {
        bool hasPermission = false;

        var storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) hasPermission = true;

        if (!hasPermission) {
          storageStatus = await Permission.storage.request();
          hasPermission = storageStatus.isGranted;
        }
        // Try manage external storage if regular storage isn't enough (Android 11+)
        if (!hasPermission) {
           var manageStatus = await Permission.manageExternalStorage.status;
           if(manageStatus.isGranted) hasPermission = true;
           else {
             manageStatus = await Permission.manageExternalStorage.request();
             hasPermission = manageStatus.isGranted;
           }
        }

        if (!hasPermission) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Storage permission is required to pick PDF files. Please grant it in settings.'),
                backgroundColor: Colors.red),
          );
          return;
        }
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        final file = result.files.first;
        final name = file.name.replaceAll('.pdf', '');
        final appDir = await getApplicationDocumentsDirectory();
        final pdfsDir = Directory('${appDir.path}/pdfs');
        await pdfsDir.create(recursive: true);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final savedFile = File('${pdfsDir.path}/$fileName');

        if (file.path != null) {
          await File(file.path!).copy(savedFile.path);
        }

        final pdfLecture = PDFLecture(name: name, pdfPath: savedFile.path);

        if (isTheory) {
          widget.onAddTheory(widget.lecture.id, pdfLecture);
        } else {
          widget.onAddPractical(widget.lecture.id, pdfLecture);
        }

        setState(() {}); // Refresh UI
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF added successfully')),
        );
      }
    } catch (e) {
      print('Error picking PDF: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving PDF file: $e')),
      );
    }
  }

  Future<void> _openPDF(String? pdfPath) async {
    try {
      if (pdfPath == null || pdfPath.isEmpty) {
        print('Error: PDF path is null or empty');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: PDF file not found'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      
      final file = File(pdfPath);
      if (!await file.exists()) {
        print('Error: PDF file does not exist at path: $pdfPath');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: PDF file not found. It might have been moved or deleted.'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      
      print('Attempting to open PDF: $pdfPath');
      final result = await OpenFile.open(pdfPath);
      print('PDF open result: ${result.type} - ${result.message}');
      
      if (result.type == "error") {
        print('Error opening PDF: ${result.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error opening PDF: ${result.message}'), 
              backgroundColor: Colors.red
            ),
          );
        }
      } else if (result.type == "noAppToOpen") {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No app found to open PDF files. Please install a PDF viewer.'), 
              backgroundColor: Colors.orange
            ),
          );
        }
      } else if (result.type == "done") {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF opened successfully'),
              backgroundColor: Colors.green
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Exception while opening PDF: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleCompletion(PDFLecture pdfLecture) {
    final updatedLecture = PDFLecture(
      id: pdfLecture.id,
      name: pdfLecture.name,
      pdfPath: pdfLecture.pdfPath,
      dateAdded: pdfLecture.dateAdded,
      isCompleted: !pdfLecture.isCompleted,
    );
    if (widget.lecture.theoryLectures.any((l) => l.id == pdfLecture.id)) {
      widget.onUpdateTheory(widget.lecture.id, updatedLecture);
    } else {
      widget.onUpdatePractical(widget.lecture.id, updatedLecture);
    }
    setState(() {
      final theoryIndex = widget.lecture.theoryLectures.indexWhere((l) => l.id == pdfLecture.id);
      if (theoryIndex != -1) widget.lecture.theoryLectures[theoryIndex] = updatedLecture;
      final practicalIndex = widget.lecture.practicalLectures.indexWhere((l) => l.id == pdfLecture.id);
      if (practicalIndex != -1) widget.lecture.practicalLectures[practicalIndex] = updatedLecture;
    });
    updateWidgets(null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(updatedLecture.isCompleted ? 'Marked as completed' : 'Marked as incomplete'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showDeleteConfirmation(PDFLecture pdfLecture, bool isTheory) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lecture'),
        content: Text('Are you sure you want to delete "${pdfLecture.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            // --- MODIFIED: Make this function async ---
            onPressed: () async {
              // --- MODIFIED: Use try...catch ---
              try {
                if (pdfLecture.pdfPath != null) {
                  // Await the deletion within the try block
                  await File(pdfLecture.pdfPath!).delete();
                  print('Successfully deleted PDF: ${pdfLecture.pdfPath}');
                }
              } catch (e) {
                // Catch any errors during deletion
                print("Error deleting PDF file: $e");
                // Optionally, show a message to the user here
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text('Could not delete PDF file: $e'), backgroundColor: Colors.orange),
                // );
              }
              // --- END MODIFICATION ---

              // This part remains the same, deleting from the list/state
              if (isTheory) {
                widget.onDeleteTheory(widget.lecture.id, pdfLecture.id);
                setState(() {
                  widget.lecture.theoryLectures
                      .removeWhere((l) => l.id == pdfLecture.id);
                });
              } else {
                widget.onDeletePractical(widget.lecture.id, pdfLecture.id);
                setState(() {
                  widget.lecture.practicalLectures
                      .removeWhere((l) => l.id == pdfLecture.id);
                });
              }
              Navigator.pop(context); // Close the dialog

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lecture deleted'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            // --- END MODIFICATION ---
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // --- ADDED/MODIFIED FOR AI FEATURES ---

  Future<String?> _getOrExtractPdfText(String? pdfPath) async {
    if (pdfPath == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('PDF path is missing.'), backgroundColor: Colors.red),
       );
       return null;
    }
    if (_currentPdfText != null && _currentPdfPath == pdfPath) {
      return _currentPdfText;
    }

    setState(() => _isProcessingAi = true);
    final extractedText = await _aiService.extractPdfText(pdfPath);
    setState(() => _isProcessingAi = false);

    if (extractedText == null || extractedText.trim().isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not extract text from PDF. It might be image-based or protected.'), backgroundColor: Colors.orange),
        );
      }
      _currentPdfText = null;
      _currentPdfPath = null;
      return null;
    }

    _currentPdfText = extractedText;
    _currentPdfPath = pdfPath;
    return _currentPdfText;
  }

  void _showAiOptions(BuildContext context, String? pdfPath) async {
    final text = await _getOrExtractPdfText(pdfPath);
    if (text == null || !mounted) return;

    // Use a full page instead of a modal bottom sheet to avoid rendering glitches
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AIToolsPage(
          text: text,
          performAiAction: _performAiAction,
          lectureId: widget.lecture.id,
          lectureName: widget.lecture.name,
        ),
      ),
    );
  }

  void _performAiAction(String pdfText, String action, {int? questionCount = 10, String? quizType = 'mixed', String? difficulty = 'medium'}) async {
    // Get the PDF name from the current PDF path
    String? pdfName;
    if (_currentPdfPath != null) {
      final pdfFile = File(_currentPdfPath!);
      if (pdfFile.existsSync()) {
        // Extract just the filename without extension
        pdfName = pdfFile.path.split('/').last.split('\\').last;
        if (pdfName.contains('.pdf')) {
          pdfName = pdfName.substring(0, pdfName.lastIndexOf('.pdf'));
        }
        // Remove timestamp prefix if it exists (from the format we use when saving PDFs)
        if (pdfName.contains('_')) {
          final parts = pdfName.split('_');
          if (parts.length > 1 && int.tryParse(parts[0]) != null) {
            // If the first part is a number (timestamp), remove it
            pdfName = parts.sublist(1).join('_');
          }
        }
      }
    }
    setState(() => _isProcessingAi = true);
    String? result;
    String title = '';
    List<Map<String, String>>? flashcards;
    Map<String, String>? studyGuide;

    // Ensure non-null values for parameters
    final int nonNullQuestionCount = questionCount ?? 10;
    final String nonNullQuizType = quizType ?? 'mixed';

    // Use the quiz type directly now that we have a separate difficulty parameter
    String baseQuizType = nonNullQuizType;
    String difficultyLevel = difficulty ?? 'medium';

    try {
      switch (action) {
        case 'comprehensive_guide':
          title = 'Comprehensive Study Guide';
          studyGuide = await _aiService.generateComprehensiveStudyGuide(pdfText);
          // Create a preview of the study guide
          if (studyGuide != null && studyGuide.isNotEmpty) {
            result = 'Generated a complete study guide with the following sections:\n\n';
            if (studyGuide.containsKey('summary')) {
              result += '• Summary\n';
            }
            if (studyGuide.containsKey('important_topics')) {
              result += '• Important Topics\n';
            }
            if (studyGuide.containsKey('key_terms')) {
              result += '• Key Terms\n';
            }
            if (studyGuide.containsKey('study_roadmap')) {
              result += '• Study Roadmap\n';
            }
            if (studyGuide.containsKey('discussion_questions')) {
              result += '• Discussion Questions\n';
            }
          }
          break;
        case 'summary':
          title = 'Summary';
          result = await _aiService.summarizePdf(pdfText);
          break;
        case 'key_points':
          title = 'Key Points';
          result = await _aiService.getKeyPoints(pdfText);
          break;
        case 'important_topics':
          title = 'Important Topics';
          result = await _aiService.getImportantTopics(pdfText);
          break;
        case 'key_terms':
          title = 'Key Terms';
          result = await _aiService.getKeyTerms(pdfText);
          break;
        case 'study_roadmap':
          title = 'Study Roadmap';
          result = await _aiService.getStudyRoadmap(pdfText);
          break;
        case 'discussion_questions':
          title = 'Discussion Questions';
          result = await _aiService.getDiscussionQuestions(pdfText);
          break;
        case 'flashcards':
          title = 'Flashcards';
          flashcards = await _aiService.generateFlashcards(pdfText, count: nonNullQuestionCount);

          // Add PDF name to each flashcard
          if (flashcards != null && pdfName != null) {
            for (var card in flashcards) {
              card['pdfName'] = pdfName;
            }
          }
          // Convert flashcards to a preview string for the dialog
          if (flashcards != null && flashcards.isNotEmpty) {
            result = 'Generated ${flashcards.length} flashcards:\n\n';
            for (int i = 0; i < min(3, flashcards.length); i++) {
              if (result != null) {
                result += 'Card ${i + 1}:\n';
                result += 'Front: ${flashcards[i]['front']}\n';
                result += 'Back: ${flashcards[i]['back']}\n\n';
              }
            }
            if (flashcards.length > 3 && result != null) {
              result += '...';
            }
          }
          break;
        case 'questions':
          title = 'Practice Questions';
          result = await _aiService.generateQuestions(pdfText, count: nonNullQuestionCount, type: nonNullQuizType, difficulty: difficultyLevel);
          break;
      }
    } finally {
      setState(() => _isProcessingAi = false);
    }

    if (mounted) {
      if (action == 'comprehensive_guide' && studyGuide != null && studyGuide.isNotEmpty) {
        // Save the study guide and go directly to the page without confirmation dialog
        final studyGuideService = StudyGuideService();
        final newGuide = StudyGuide(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'Study Guide for ${widget.lecture.name}',
            lectureId: widget.lecture.id,
            lectureName: widget.lecture.name,
            createdAt: DateTime.now(),
            content: studyGuide, // Removed null assertion operator
          );
          await studyGuideService.saveStudyGuide(newGuide);

          // Navigate to the study guide page
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudyGuidePage(
                  studyGuide: studyGuide as Map<String, String>, // Cast to required type
                  title: 'Study Guide for ${widget.lecture.name}',
                ),
              ),
            );
          }
      } else if (action == 'questions' && result != null) {
        // Process questions differently for multiple choice vs other types
        List<String> questions = [];

        if (baseQuizType == 'multiple_choice' || baseQuizType == 'mixed') {
          // For multiple choice, we need to include the options with each question
          final lines = result.split('\n');
          List<String> currentQuestion = [];

          for (int i = 0; i < lines.length; i++) {
            final line = lines[i].trim();

            // Start of a new question
            if (line.startsWith('Q: ')) {
              // If we have a previous question, add it to the list
              if (currentQuestion.isNotEmpty) {
                questions.add(currentQuestion.join('\n'));
                currentQuestion = [];
              }
              currentQuestion.add(line);
            } 
            // Option lines or CORRECT: line for the current question
            else if (line.startsWith('A)') || line.startsWith('B)') || 
                     line.startsWith('C)') || line.startsWith('D)') ||
                     line.startsWith('CORRECT:')) {
              if (currentQuestion.isNotEmpty) {
                currentQuestion.add(line);
              }
            }
            // Empty line - ignore
            else if (line.isEmpty) {
              continue;
            }
            // Other text might be part of the current question
            else if (currentQuestion.isNotEmpty) {
              // Only add if it's not just a separator or other formatting
              if (line.length > 1 && !line.startsWith('---')) {
                currentQuestion.add(line);
              }
            }
          }

          // Add the last question if there is one
          if (currentQuestion.isNotEmpty) {
            questions.add(currentQuestion.join('\n'));
          }
        } else {
          // For other question types, just get lines starting with Q:
          questions = result
              .split('\n')
              .where((line) => line.trim().startsWith('Q: '))
              .map((line) => line.trim())
              .toList();
        }

        if (questions.isNotEmpty && mounted) {
          // Skip preview dialog and go directly to the exam page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExamPage(
                questions: questions,
                pdfText: pdfText,
                aiService: _aiService,
                quizType: nonNullQuizType,
              ),
            ),
          );
        } else {
          _showResultDialog('No Questions', 'The AI did not generate any questions, or failed to format them. Please try again.\n\nRaw response: $result');
        }
      } else if (action == 'flashcards' && flashcards != null && flashcards.isNotEmpty) {
        // Go directly to the flashcards page without confirmation dialog
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FlashcardsPage(
                flashcards: flashcards,
                title: 'AI Generated Flashcards for ${widget.lecture.name}',
                lectureId: widget.lecture.id,
                // Pass the PDF name to the FlashcardsPage
              ),
            ),
          );
        }
      } else if (result != null) {
        _showResultDialog(title, result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get AI response.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Show a preview dialog with the option to proceed or cancel

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: 'Copy to clipboard',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            content,
            style: const TextStyle(height: 1.5),
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0.0),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStatCard(String title, String count, IconData icon, Color color, double progress) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleSectionHeader(String title, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSimplePDFCard(PDFLecture pdf, bool isTheory, Color color) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pdf.isCompleted 
              ? Colors.green.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (pdf.isCompleted ? Colors.green : color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.picture_as_pdf,
                color: pdf.isCompleted ? Colors.green : color,
                size: 24,
              ),
            ),
            title: Text(
              pdf.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                decoration: pdf.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              pdf.isCompleted ? 'Completed' : 'Not completed',
              style: TextStyle(
                color: pdf.isCompleted ? Colors.green : theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            trailing: IconButton(
              onPressed: () => _toggleCompletion(pdf),
              icon: Icon(
                pdf.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                color: pdf.isCompleted ? Colors.green : Colors.grey,
              ),
              tooltip: pdf.isCompleted ? 'Mark as incomplete' : 'Mark as complete',
            ),
            onTap: () => _openPDF(pdf.pdfPath),
          ),
          // Action buttons row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessingAi ? null : () => _showAiOptions(context, pdf.pdfPath),
                    icon: Icon(Icons.psychology, size: 16, color: _isProcessingAi ? null : Colors.purple),
                    label: Text('AI Tools', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.withOpacity(0.1),
                      foregroundColor: Colors.purple,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _openPDF(pdf.pdfPath),
                  icon: Icon(Icons.open_in_new, size: 16),
                  label: Text('Open', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.withOpacity(0.1),
                    foregroundColor: color,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showDeleteConfirmation(pdf, isTheory),
                  icon: Icon(Icons.delete_outline, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.all(8),
                  ),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleAddButton(bool isTheory, Color color) {
    Theme.of(context);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: () => _pickAndSavePDF(isTheory),
        icon: Icon(Icons.add, color: color),
        label: Text(
          'Add ${isTheory ? "Theory" : "Practical"} PDF',
          style: TextStyle(color: color),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          side: BorderSide(color: color.withOpacity(0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, bool isTheory) {
    final theme = Theme.of(context);
    final color = isTheory ? Colors.blue : Colors.orange;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.picture_as_pdf_outlined,
              size: 32,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology, size: 16, color: Colors.purple),
              const SizedBox(width: 4),
              Text(
                'AI tools available after adding PDFs',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.purple,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _pickAndSavePDF(isTheory),
            icon: const Icon(Icons.add),
            label: const Text('Add PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  

  @override
  Widget build(BuildContext context) {
    final totalTheory = widget.lecture.theoryLectures.length;
    final completedTheory = widget.lecture.theoryLectures.where((l) => l.isCompleted).length;
    final totalPractical = widget.lecture.practicalLectures.length;
    final completedPractical = widget.lecture.practicalLectures.where((l) => l.isCompleted).length;
    final totalLectures = totalTheory + totalPractical;
    final completedLectures = completedTheory + completedPractical;
    final overallProgress = totalLectures == 0 ? 0.0 : completedLectures / totalLectures;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.lecture.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (widget.lecture.subtitle.isNotEmpty)
              Text(
                widget.lecture.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: overallProgress >= 0.8 ? Colors.green.withOpacity(0.1) : theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  overallProgress >= 0.8 ? Icons.check_circle : Icons.analytics,
                  size: 16,
                  color: overallProgress >= 0.8 ? Colors.green : theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${(overallProgress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: overallProgress >= 0.8 ? Colors.green : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Stats Card
                if (totalLectures > 0) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Progress Overview',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSimpleStatCard(
                                'Theory',
                                '$completedTheory/$totalTheory',
                                Icons.menu_book_outlined,
                                Colors.blue,
                                totalTheory == 0 ? 0 : completedTheory / totalTheory,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSimpleStatCard(
                                'Practical',
                                '$completedPractical/$totalPractical',
                                Icons.science_outlined,
                                Colors.orange,
                                totalPractical == 0 ? 0 : completedPractical / totalPractical,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // AI Tools Info Card
                if (totalLectures > 0) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.purple.withOpacity(0.1),
                          Colors.deepPurple.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.purple.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.psychology,
                            color: Colors.purple,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🚀 AI Study Tools Available',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Generate summaries, flashcards, quizzes & more from your PDFs',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.auto_awesome,
                          color: Colors.purple,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Theory Section
                _buildSimpleSectionHeader('Theory Materials', Icons.menu_book_outlined, Colors.blue),
                const SizedBox(height: 12),
                if (widget.lecture.theoryLectures.isEmpty)
                  _buildEmptyState('No theory materials yet', 'Add your first theory PDF', true)
                else ...[
                  ...widget.lecture.theoryLectures.map((pdf) => 
                    _buildSimplePDFCard(pdf, true, Colors.blue)
                  ),
                  const SizedBox(height: 8),
                  _buildSimpleAddButton(true, Colors.blue),
                ],

                const SizedBox(height: 32),

                // Practical Section
                _buildSimpleSectionHeader('Practical Materials', Icons.science_outlined, Colors.orange),
                const SizedBox(height: 12),
                if (widget.lecture.practicalLectures.isEmpty)
                  _buildEmptyState('No practical materials yet', 'Add your first practical PDF', false)
                else ...[
                  ...widget.lecture.practicalLectures.map((pdf) => 
                    _buildSimplePDFCard(pdf, false, Colors.orange)
                  ),
                  const SizedBox(height: 8),
                  _buildSimpleAddButton(false, Colors.orange),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
          
          // Loading Overlay
          if (_isProcessingAi)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  margin: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'AI is processing...',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  
}