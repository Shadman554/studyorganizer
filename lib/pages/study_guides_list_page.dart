// lib/pages/study_guides_list_page.dart
import 'package:flutter/material.dart';
import '../models/study_guide_model.dart';
import '../services/study_guide_service.dart';
import 'study_guide_page.dart';
import 'package:intl/intl.dart';

class StudyGuidesListPage extends StatefulWidget {
  final String? lectureId;
  final String? lectureName;

  const StudyGuidesListPage({
    super.key, 
    this.lectureId,
    this.lectureName,
  });

  @override
  State<StudyGuidesListPage> createState() => _StudyGuidesListPageState();
}

class _StudyGuidesListPageState extends State<StudyGuidesListPage> {
  final StudyGuideService _studyGuideService = StudyGuideService();
  List<StudyGuide> _studyGuides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudyGuides();
  }

  Future<void> _loadStudyGuides() async {
    setState(() => _isLoading = true);
    
    if (widget.lectureId != null) {
      _studyGuides = await _studyGuideService.getStudyGuidesForLecture(widget.lectureId!);
    } else {
      _studyGuides = await _studyGuideService.getStudyGuides();
    }
    
    // Sort by most recent first
    _studyGuides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.lectureName != null 
            ? 'Study Guides - ${widget.lectureName}'
            : 'All Study Guides'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudyGuides,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _studyGuides.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 80,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No study guides yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generate a new study guide to get started',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _studyGuides.length,
                  itemBuilder: (context, index) {
                    final guide = _studyGuides[index];
                    final formattedDate = DateFormat('MMM d, yyyy - h:mm a').format(guide.createdAt);
                    
                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.blue[700]!.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudyGuidePage(
                                studyGuide: guide.content,
                                title: guide.title,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.menu_book,
                                    color: Colors.blue[300],
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      guide.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.white),
                                    onSelected: (value) async {
                                      if (value == 'delete') {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: Colors.grey[900],
                                            title: const Text('Delete Study Guide', style: TextStyle(color: Colors.white)),
                                            content: const Text(
                                              'Are you sure you want to delete this study guide? This action cannot be undone.',
                                              style: TextStyle(color: Colors.white70),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        
                                        if (confirmed == true) {
                                          await _studyGuideService.deleteStudyGuide(guide.id);
                                          _loadStudyGuides();
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Lecture: ${guide.lectureName}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Created: $formattedDate',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Tap to view',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue[300],
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: Colors.blue[300],
                                    size: 16,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: widget.lectureId != null
          ? FloatingActionButton(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.pop(context, 'generate');
              },
              child: const Icon(Icons.add),
              tooltip: 'Generate New Study Guide',
            )
          : null,
    );
  }
}
