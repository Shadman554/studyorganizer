// lib/pages/study_guide_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StudyGuidePage extends StatefulWidget {
  final Map<String, String> studyGuide;
  final String title;

  const StudyGuidePage({
    super.key,
    required this.studyGuide,
    required this.title,
  });

  @override
  State<StudyGuidePage> createState() => _StudyGuidePageState();
}

class _StudyGuidePageState extends State<StudyGuidePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _sections = ['summary', 'important_topics', 'key_terms', 'study_roadmap', 'discussion_questions'];
  final List<String> _sectionTitles = ['Summary', 'Important Topics', 'Key Terms', 'Study Roadmap', 'Discussion Questions'];
  final List<IconData> _sectionIcons = [
    Icons.summarize_outlined,
    Icons.topic_outlined,
    Icons.key_outlined,
    Icons.map_outlined,
    Icons.yard,
  ];

  List<String> _availableSections = [];

  @override
  void initState() {
    super.initState();
    _updateAvailableSections();
    _tabController = TabController(
      length: _availableSections.length,
      vsync: this,
    );
  }

  // Helper to update available sections based on studyGuide content
  void _updateAvailableSections() {
    _availableSections = _sections.where((section) =>
      widget.studyGuide.containsKey(section) &&
      widget.studyGuide[section]!.isNotEmpty
    ).toList();
  }

  @override
  void didUpdateWidget(covariant StudyGuidePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the study guide content changes, re-evaluate available sections and tab controller
    if (widget.studyGuide != oldWidget.studyGuide) {
      _updateAvailableSections();
      _tabController.dispose(); // Dispose old controller
      _tabController = TabController(
        length: _availableSections.length,
        vsync: this,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If there's only one section or the full content, show a simpler UI
    if (_availableSections.isEmpty || (_availableSections.length == 1 && _availableSections.first == 'full_content')) {
      return _buildSinglePageView();
    }

    // Determine colors from theme
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = colorScheme.primary;
    final Color onSurfaceColor = colorScheme.onSurface; // For unselected items

    return Scaffold(
      backgroundColor: colorScheme.surface, // Use theme surface color
      appBar: AppBar(
        backgroundColor: colorScheme.surface, // Use theme surface color
        foregroundColor: colorScheme.onSurface, // Use theme onSurface color for text/icons
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: primaryColor, // Use primary color for indicator
          labelColor: primaryColor, // Use primary color for selected label
          unselectedLabelColor: onSurfaceColor.withOpacity(0.6), // Muted for unselected
          tabs: _availableSections.map((section) {
            final index = _sections.indexOf(section);
            return Tab(
              icon: Icon(_sectionIcons[index]),
              text: _sectionTitles[index],
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _availableSections.map((section) {
          return _buildSectionContent(section);
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Copy the current section to clipboard
          final currentSection = _availableSections[_tabController.index];
          final content = widget.studyGuide[currentSection] ?? '';
          Clipboard.setData(ClipboardData(text: content));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Copied to clipboard', style: TextStyle(color: colorScheme.onPrimary))),
          );
        },
        backgroundColor: isDark ? Colors.teal : Colors.teal[700],
        foregroundColor: Colors.white,
        child: const Icon(Icons.copy),
        tooltip: 'Copy to clipboard',
      ),
    );
  }

  Widget _buildSinglePageView() {
    final content = widget.studyGuide.containsKey('full_content')
        ? widget.studyGuide['full_content']!
        : widget.studyGuide.values.firstWhere((element) => element.isNotEmpty, orElse: () => 'No content available.');

    final formattedContent = _formatContent(content);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: (isDark ? Colors.teal : Colors.teal[700])!.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.tealAccent : Colors.teal[700],
                ),
              ),
              Container(
                height: 2,
                width: 150,
                color: isDark ? Colors.tealAccent : Colors.teal[700],
                margin: const EdgeInsets.only(top: 8, bottom: 16),
              ),
              _buildFormattedContent(formattedContent),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: content));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Copied to clipboard', style: TextStyle(color: colorScheme.onPrimary))),
          );
        },
        backgroundColor: isDark ? Colors.teal : Colors.teal[700],
        foregroundColor: Colors.white,
        child: const Icon(Icons.copy),
        tooltip: 'Copy to clipboard',
      ),
    );
  }

  Widget _buildSectionContent(String section) {
    final content = widget.studyGuide[section] ?? '';
    final index = _sections.indexOf(section);
    final formattedContent = _formatContent(content);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header styled like About Me page
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: (isDark ? Colors.teal : Colors.teal[700])!.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _sectionIcons[index], 
                      color: isDark ? Colors.tealAccent : Colors.teal[700],
                      size: 28
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Text(
                        _sectionTitles[index],
                        style: TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.tealAccent : Colors.teal[700],
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 2,
                  width: 150,
                  color: isDark ? Colors.tealAccent : Colors.teal[700],
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                ),
                // Content with improved formatting
                _buildFormattedContent(formattedContent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Refactored _buildFormattedContent for better organization and styling
  Widget _buildFormattedContent(List<Map<String, dynamic>> contentBlocks) {
    final List<Widget> children = [];
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    for (int i = 0; i < contentBlocks.length; i++) {
      final item = contentBlocks[i];
      if (item['type'] == 'heading') {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['text'],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.tealAccent : Colors.teal[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  width: 100,
                  color: isDark ? Colors.tealAccent : Colors.teal[700],
                  margin: const EdgeInsets.only(bottom: 12),
                ),
              ],
            ),
          ),
        );
      } else if (item['type'] == 'bullet') {
        String pageRef = '';
        if (i + 1 < contentBlocks.length && contentBlocks[i + 1]['type'] == 'page_reference') {
          pageRef = contentBlocks[i + 1]['page'];
          i++; // Consume the page reference as it's handled here
        }

        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.tealAccent : Colors.teal[700],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        item['text'],
                        style: TextStyle(
                          height: 1.5, 
                          fontSize: 16, 
                          color: colorScheme.onSurface
                        ),
                      ),
                      if (pageRef.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            's.pdf (p. $pageRef)',
                            style: TextStyle(
                              fontSize: 12, 
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (item['type'] == 'paragraph') {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: SelectableText(
              item['text'],
              style: TextStyle(
                height: 1.6, 
                fontSize: 16, 
                color: colorScheme.onSurface
              ),
            ),
          ),
        );
      }
      // Page references are handled within bullets, so no separate widget for them here
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // The content formatting logic remains largely the same, but ensure it correctly identifies blocks.
  // Updated _formatContent to remove asterisks from text
  List<Map<String, dynamic>> _formatContent(String content) {
    final List<Map<String, dynamic>> blocks = [];
    final List<String> lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      if (line.isEmpty) continue;

      // Handle page references (** or **number) - KEEP THESE AS IS
      if (line.startsWith('**') && (line == '**' || RegExp(r'\*\*\d+').hasMatch(line))) {
        String pageNumber = line == '**' ? '' : line.replaceAll('**', '');
        blocks.add({
          'type': 'page_reference',
          'page': pageNumber,
        });
        continue; // Move to the next line immediately
      }

      // Handle bullet points
      if (line.startsWith('•') || line.startsWith('-') || line.startsWith('*')) {
        line = line.substring(1).trim(); // Remove the bullet character
        line = line.replaceAll('*', '');   // <<< ADDED: Remove any asterisks from the text
        if (line.isNotEmpty) { // Only add if not empty after cleaning
            blocks.add({
              'type': 'bullet',
              'text': line,
            });
        }
        continue;
      }

      // Handle headings (lines that are short and potentially followed by an empty line or another heading)
      // This heuristic remains the same for detection.
      bool isPotentialHeading = line.length < 70 && (
          (i < lines.length - 1 && lines[i + 1].trim().isEmpty) || // followed by empty line
          (line.toUpperCase() == line && line.length > 5) || // all caps, reasonable length
          (i < lines.length - 1 && _isNextLineLikelySubheading(lines[i + 1])) // followed by another short line
      );

      // We will remove asterisks *before* adding as heading or paragraph.
      String cleanedLine = line.replaceAll('*', ''); // <<< ADDED: Clean the line

      // Ensure the line isn't empty *after* cleaning before adding.
      if (cleanedLine.isEmpty) continue;

      if (isPotentialHeading) {
        blocks.add({
          'type': 'heading',
          'text': cleanedLine, // Use the cleaned line
        });
        continue;
      }

      // Regular paragraph
      blocks.add({
        'type': 'paragraph',
        'text': cleanedLine, // Use the cleaned line
      });
    }

    return blocks;
  }

  // Helper function remains the same
  bool _isNextLineLikelySubheading(String nextLine) {
    nextLine = nextLine.trim();
    return nextLine.isNotEmpty && nextLine.length < 100 &&
           !nextLine.startsWith('•') && !nextLine.startsWith('-') && !nextLine.startsWith('*');
  }
}