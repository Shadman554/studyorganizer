import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../main.dart' show Lecture;

class AnalysisPage extends StatefulWidget {
  final List<Lecture> lectures;

  const AnalysisPage({super.key, required this.lectures});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late final AiService _aiService;
  bool _isGeneratingAiInsights = false;
  Map<String, dynamic> _smartInsights = {};
  List<Map<String, dynamic>> _studyPatterns = [];
  Map<String, double> _learningVelocity = {};
  List<String> _adaptiveRecommendations = [];
  Map<String, dynamic> _predictiveAnalytics = {};
// Define the getter or field

  /// Removes Markdown italic/bold asterisks from AI text returned by OpenAI.
  String _cleanMarkdown(String input) {
    return input.replaceAll(RegExp(r'[*]'), '').trim();
  }


  @override
  void initState() {
    super.initState();
    _aiService = AiService(apiKey: 'AIzaSyAiO8RVja7tRdsWMI0RjKDeB8zAt9bGWHk');
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
    
    _fadeController.forward();
    _slideController.forward();
    
    // Generate comprehensive AI analytics if there's data
    if (widget.lectures.isNotEmpty) {
      _generateSmartAnalytics();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _generateSmartAnalytics() async {
    if (!_aiService.isValidApiKey) return;
    
    setState(() {
      _isGeneratingAiInsights = true;
    });

    try {
      await Future.wait([
        _generateLearningPatterns(),
        _calculateLearningVelocity(),
        _generatePredictiveAnalytics(),
        _generateAdaptiveRecommendations(),
        _analyzeStudyEfficiency(),
      ]);
      
      if (mounted) {
        setState(() {
          _isGeneratingAiInsights = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingAiInsights = false;
        });
      }
    }
  }

  Future<void> _generateLearningPatterns() async {
    final stats = _calculateStats();
    final prompt = '''
    Analyze this detailed study data and identify unique learning patterns:
    
    Total Subjects: ${widget.lectures.length}
    Completion Rates: Theory ${(stats['theoryProgress'] * 100).toInt()}%, Practical ${(stats['practicalProgress'] * 100).toInt()}%
    
    ${_buildDetailedSubjectData()}
    
    Identify 3-4 specific learning patterns such as:
    - Subject clustering (which subjects are completed together)
    - Learning momentum (acceleration/deceleration patterns)
    - Content type preferences
    - Difficulty adaptation patterns
    
    Return each pattern as: "Pattern: [name] | Description: [detailed analysis] | Impact: [learning impact]"
    ''';
    
    final result = await _aiService.summarizePdf(prompt);
    if (result != null && mounted) {
      String _cleanText(String input) {
        // Removes markdown asterisks used for *italic* or **bold** formatting
        return input.replaceAll(RegExp(r'[*]'), '').trim();
      }

      final patterns = result
          .split('\n')
          .where((line) => line.contains('Pattern:'))
          .map((line) {
        final parts = line.split(' | ');
        return {
          'name': _cleanText(parts[0].replaceAll('Pattern: ', '')),
          'description': parts.length > 1
              ? _cleanText(parts[1].replaceAll('Description: ', ''))
              : '',
          'impact': parts.length > 2
              ? _cleanText(parts[2].replaceAll('Impact: ', ''))
              : '',
        };
      }).toList();
      
      setState(() {
        _studyPatterns = patterns;
      });
    }
  }

  Future<void> _calculateLearningVelocity() async {
    final prompt = '''
    Calculate learning velocity metrics for each subject based on this data:
    
    ${_buildDetailedSubjectData()}
    
    For each subject, estimate:
    - Completion velocity (materials per week estimate)
    - Learning difficulty coefficient (1.0 = normal, >1.0 = challenging)
    - Retention probability (0-1 based on completion patterns)
    
    Format as: "Subject: [name] | Velocity: [number] | Difficulty: [number] | Retention: [number]"
    ''';
    
    final result = await _aiService.summarizePdf(prompt);
    if (result != null && mounted) {
      final velocityData = <String, double>{};
      result.split('\n').where((line) => line.contains('Subject:')).forEach((line) {
        final parts = line.split(' | ');
        if (parts.length >= 4) {
          final subject = _cleanMarkdown(parts[0].replaceAll('Subject: ', ''));
          final velocity = double.tryParse(parts[1].replaceAll('Velocity: ', '')) ?? 0.0;
          velocityData[subject] = velocity;
        }
      });
      
      setState(() {
        _learningVelocity = velocityData;
      });
    }
  }

  Future<void> _generatePredictiveAnalytics() async {
    final stats = _calculateStats();
    final prompt = '''
    Generate predictive analytics based on current study patterns:
    
    Current Progress: ${(stats['overallPercentage'] * 100).toInt()}%
    ${_buildDetailedSubjectData()}
    
    Predict:
    1. Estimated completion date for all subjects
    2. Risk factors for incomplete subjects
    3. Optimal study schedule recommendations
    4. Performance trending (improving/declining/stable)
    
    Format as structured predictions with confidence levels.
    ''';
    
    final result = await _aiService.summarizePdf(prompt);
    if (result != null && mounted) {
      setState(() {
        _predictiveAnalytics = {
          'completion_forecast': _extractPrediction(result, 'completion'),
          'risk_assessment': _extractPrediction(result, 'risk'),
          'performance_trend': _extractPrediction(result, 'trending'),
        };
      });
    }
  }

  Future<void> _generateAdaptiveRecommendations() async {
    final stats = _calculateStats();
    final prompt = '''
    Generate 5-7 highly specific, adaptive study recommendations based on:
    
    Progress Data: ${(stats['overallPercentage'] * 100).toInt()}% complete
    Learning Patterns: ${_studyPatterns.map((p) => p['name']).join(', ')}
    ${_buildDetailedSubjectData()}
    
    Each recommendation should be:
    - Highly specific and actionable
    - Personalized to current progress
    - Include reasoning and expected outcome
    
    Format: "Action: [specific action] | Reason: [why] | Expected: [outcome]"
    ''';
    
    final result = await _aiService.summarizePdf(prompt);
    if (result != null && mounted) {
      final recommendations = result.split('\n')
          .where((line) => line.contains('Action:'))
          .map((line) => _cleanMarkdown(line.trim()))
          .toList();
      
      setState(() {
        _adaptiveRecommendations = recommendations;
      });
    }
  }

  Future<void> _analyzeStudyEfficiency() async {
    final prompt = '''
    Analyze study efficiency and generate unique insights:
    
    ${_buildDetailedSubjectData()}
    
    Calculate:
    - Study efficiency score (0-100)
    - Resource utilization analysis
    - Learning bottlenecks identification
    - Optimization opportunities
    
    Provide actionable efficiency improvements.
    ''';
    
    final result = await _aiService.summarizePdf(prompt);
    if (result != null && mounted) {
      setState(() {
        _smartInsights['efficiency'] = result;
      });
    }
  }

  String _buildDetailedSubjectData() {
    return widget.lectures.map((lecture) {
      final theoryComplete = lecture.theoryLectures.where((l) => l.isCompleted).length;
      final practicalComplete = lecture.practicalLectures.where((l) => l.isCompleted).length;
      final theoryTotal = lecture.theoryLectures.length;
      final practicalTotal = lecture.practicalLectures.length;
      
      return '''
Subject: ${lecture.name}
- Theory: $theoryComplete/$theoryTotal (${theoryTotal > 0 ? (theoryComplete/theoryTotal*100).toInt() : 0}%)
- Practical: $practicalComplete/$practicalTotal (${practicalTotal > 0 ? (practicalComplete/practicalTotal*100).toInt() : 0}%)
- Total Materials: ${theoryTotal + practicalTotal}
- Completion: ${theoryTotal + practicalTotal > 0 ? ((theoryComplete + practicalComplete)/(theoryTotal + practicalTotal)*100).toInt() : 0}%
''';
    }).join('\n');
  }

  String _extractPrediction(String text, String type) {
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.toLowerCase().contains(type)) {
        return _cleanMarkdown(line.trim());
      }
    }
    return 'Analysis pending...';
  }

  Map<String, dynamic> _calculateStats() {
    int totalOverallTheory = 0;
    int completedOverallTheory = 0;
    int totalOverallPractical = 0;
    int completedOverallPractical = 0;
    List<Map<String, dynamic>> subjectProgressList = [];
    int fullyCompletedSubjects = 0;

    for (var lecture in widget.lectures) {
      final progressData = _getLectureProgress(lecture);
      subjectProgressList.add(progressData);

      totalOverallTheory += progressData['theoryTotal'] as int;
      completedOverallTheory += progressData['theoryCompleted'] as int;
      totalOverallPractical += progressData['practicalTotal'] as int;
      completedOverallPractical += progressData['practicalCompleted'] as int;

      if (progressData['progress'] == 1.0 && progressData['total'] > 0) {
        fullyCompletedSubjects++;
      }
    }

    int totalOverallLectures = totalOverallTheory + totalOverallPractical;
    int completedOverallLectures = completedOverallTheory + completedOverallPractical;
    double overallPercentage = totalOverallLectures == 0 ? 0 : completedOverallLectures / totalOverallLectures;
    double theoryProgress = totalOverallTheory == 0 ? 0 : completedOverallTheory / totalOverallTheory;
    double practicalProgress = totalOverallPractical == 0 ? 0 : completedOverallPractical / totalOverallPractical;

    subjectProgressList.sort((a, b) => (b['progress'] as double).compareTo(a['progress'] as double));

    String? strongestSubject;
    if (subjectProgressList.isNotEmpty && (subjectProgressList.first['progress'] as double) >= 0.8) {
      strongestSubject = subjectProgressList.first['name'] as String;
    }

    String? weakestSubject;
    if (subjectProgressList.isNotEmpty) {
      final potentialWeakest = subjectProgressList
          .where((s) => (s['progress'] as double) < 0.6 && (s['total'] as int > 0))
          .toList();
      if (potentialWeakest.isNotEmpty) {
        potentialWeakest.sort((a, b) => (a['progress'] as double).compareTo(b['progress'] as double));
        weakestSubject = potentialWeakest.first['name'] as String;
      }
    }

    return {
      'overallPercentage': overallPercentage,
      'theoryProgress': theoryProgress,
      'practicalProgress': practicalProgress,
      'fullyCompletedSubjects': fullyCompletedSubjects,
      'strongestSubject': strongestSubject,
      'weakestSubject': weakestSubject,
      'subjectProgressList': subjectProgressList,
      'totalOverallTheory': totalOverallTheory,
      'completedOverallTheory': completedOverallTheory,
      'totalOverallPractical': totalOverallPractical,
      'completedOverallPractical': completedOverallPractical,
      'totalOverallLectures': totalOverallLectures,
      'completedOverallLectures': completedOverallLectures,
    };
  }

  // Helper to calculate progress for a single lecture
  Map<String, dynamic> _getLectureProgress(Lecture lecture) {
    int theoryTotal = lecture.theoryLectures.length;
    int theoryCompleted = lecture.theoryLectures.where((l) => l.isCompleted).length;
    int practicalTotal = lecture.practicalLectures.length;
    int practicalCompleted = lecture.practicalLectures.where((l) => l.isCompleted).length;
    int totalLectures = theoryTotal + practicalTotal;
    int completedLectures = theoryCompleted + practicalCompleted;
    double progress = totalLectures == 0 ? 0 : completedLectures / totalLectures;

    return {
      'name': lecture.name,
      'total': totalLectures,
      'completed': completedLectures,
      'progress': progress,
      'theoryTotal': theoryTotal,
      'theoryCompleted': theoryCompleted,
      'practicalTotal': practicalTotal,
      'practicalCompleted': practicalCompleted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _calculateStats();

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.psychology_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Smart Study Companion'),
          ],
        ),
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: theme.colorScheme.surface,
        actions: [
          IconButton(
            onPressed: _generateSmartAnalytics,
            icon: Icon(
              _isGeneratingAiInsights ? Icons.auto_fix_high : Icons.refresh,
              color: theme.colorScheme.primary,
            ),
            tooltip: 'Regenerate Smart Analytics',
          ),
        ],
      ),
      body: widget.lectures.isEmpty
          ? _buildEmptyState(context, theme)
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  slivers: [
                    // Smart Insights Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildSmartInsightsHeader(context, theme),
                      ),
                    ),
                    
                    // Learning Patterns Section
                    if (_studyPatterns.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildLearningPatternsSection(context, theme),
                        ),
                      ),
                    
                    // Predictive Analytics Section
                    if (_predictiveAnalytics.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildPredictiveAnalyticsSection(context, theme),
                        ),
                      ),
                    
                    // Learning Velocity Visualization
                    if (_learningVelocity.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildLearningVelocitySection(context, theme),
                        ),
                      ),
                    
                    // Adaptive Recommendations
                    if (_adaptiveRecommendations.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildAdaptiveRecommendationsSection(context, theme),
                        ),
                      ),
                    
                    // Traditional Progress Overview (Enhanced)
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildEnhancedOverallProgress(context, theme, stats),
                          const SizedBox(height: 24),
                          _buildSectionTitle(context, "🎯 Performance Intelligence"),
                          const SizedBox(height: 16),
                          _buildIntelligentProgressGrid(context, theme, stats),
                          const SizedBox(height: 24),
                          if (stats['subjectProgressList'].isNotEmpty) ...[
                            _buildSectionTitle(context, "📚 Subject Deep Analysis"),
                            const SizedBox(height: 16),
                          ],
                        ]),
                      ),
                    ),
                    
                    // Enhanced Subject Progress List
                    if (stats['subjectProgressList'].isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final subjectData = stats['subjectProgressList'][index];
                              return _buildIntelligentSubjectTile(context, theme, subjectData, index);
                            },
                            childCount: stats['subjectProgressList'].length,
                          ),
                        ),
                      ),
                    
                    // Loading Overlay
                    if (_isGeneratingAiInsights)
                      SliverToBoxAdapter(
                        child: Container(
                          height: 200,
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.purple.withOpacity(0.1), Colors.blue.withOpacity(0.1)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [Colors.purple, Colors.blue]),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '🧠 AI Brain Analyzing...',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Generating personalized insights',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    
                    // Bottom spacing
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No Data to Analyze",
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Add lectures and complete PDFs to unlock powerful AI-driven insights and analytics.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology, size: 16, color: Colors.purple),
              const SizedBox(width: 4),
              Text(
                'AI-powered study recommendations',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.purple,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }






  Widget _buildSmartInsightsHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.withOpacity(0.15),
            Colors.blue.withOpacity(0.15),
            Colors.cyan.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.purple, Colors.blue]),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🚀 AI-Powered Study Intelligence',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Personalized learning analytics & predictive insights',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMetricPill('Patterns', _studyPatterns.length.toString(), Colors.purple),
              const SizedBox(width: 12),
              _buildMetricPill('Velocity', '${_learningVelocity.length}x', Colors.blue),
              const SizedBox(width: 12),
              _buildMetricPill('Insights', _adaptiveRecommendations.length.toString(), Colors.cyan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningPatternsSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, "🧩 Learning Patterns Discovery"),
        const SizedBox(height: 16),
        ...List.generate(_studyPatterns.length, (index) {
          final pattern = _studyPatterns[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.1),
                  Colors.pink.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.psychology, color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pattern['name'] ?? 'Learning Pattern',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  pattern['description'] ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
                ),
                if (pattern['impact'] != null && pattern['impact'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Impact: ${pattern['impact'].toString().replaceFirst(RegExp(r'^[Ii]mpact:?\\s*'), '')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPredictiveAnalyticsSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, "🔮 Predictive Analytics"),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.indigo.withOpacity(0.1),
                Colors.purple.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _buildPredictionCard(
                '📅 Completion Forecast',
                _predictiveAnalytics['completion_forecast'] ?? 'Analyzing patterns...',
                Colors.indigo,
              ),
              const SizedBox(height: 16),
              _buildPredictionCard(
                '⚠️ Risk Assessment',
                _predictiveAnalytics['risk_assessment'] ?? 'Evaluating challenges...',
                Colors.red,
              ),
              const SizedBox(height: 16),
              _buildPredictionCard(
                '📈 Performance Trend',
                _predictiveAnalytics['performance_trend'] ?? 'Tracking improvements...',
                Colors.green,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPredictionCard(String title, String content, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningVelocitySection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, "🚀 Learning Velocity Analysis"),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.teal.withOpacity(0.1),
                Colors.green.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.withOpacity(0.3)),
          ),
          child: Column(
            children: _learningVelocity.entries.map((entry) {
              final velocity = entry.value;
              final color = velocity > 0.7 ? Colors.green : velocity > 0.4 ? Colors.orange : Colors.red;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${(velocity * 100).toInt()}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _getVelocityDescription(velocity),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: velocity.clamp(0.0, 1.0),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  String _getVelocityDescription(double velocity) {
    if (velocity > 0.8) return 'Excellent pace';
    if (velocity > 0.6) return 'Good progress';
    if (velocity > 0.4) return 'Steady learning';
    if (velocity > 0.2) return 'Needs attention';
    return 'Critical review needed';
  }

  Widget _buildAdaptiveRecommendationsSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, "🎯 Adaptive Recommendations"),
        const SizedBox(height: 16),
        ...List.generate(_adaptiveRecommendations.length, (index) {
          final recommendation = _adaptiveRecommendations[index];
          final parts = recommendation.split(' | ');
          final action = parts.isNotEmpty ? parts[0].replaceAll('Action: ', '') : recommendation;
          final reason = parts.length > 1 ? parts[1].replaceAll('Reason: ', '') : '';
          final expected = parts.length > 2 ? parts[2].replaceAll('Expected: ', '') : '';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.1),
                  Colors.cyan.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        action,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reason,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (expected.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            expected,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEnhancedOverallProgress(BuildContext context, ThemeData theme, Map<String, dynamic> stats) {
    final percentage = stats['overallPercentage'] as double;
    final completed = stats['completedOverallLectures'] as int;
    final total = stats['totalOverallLectures'] as int;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.15),
            Colors.purple.withOpacity(0.1),
            Colors.blue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "🎯 Intelligent Progress",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  total > 0 ? "$completed of $total units completed" : "No units yet",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getProgressInsight(percentage),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _getProgressColor(percentage),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.3),
                        Colors.purple.withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: percentage,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary, Colors.purple],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: percentage),
            duration: const Duration(milliseconds: 2000),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Container(
                width: 100,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 10,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getProgressColor(value),
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${(value * 100).toInt()}%",
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            _getProgressEmoji(value),
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getProgressInsight(double percentage) {
    if (percentage >= 0.9) return "🎉 Outstanding achievement!";
    if (percentage >= 0.7) return "🚀 Excellent progress!";
    if (percentage >= 0.5) return "💪 Good momentum!";
    if (percentage >= 0.3) return "📈 Building progress...";
    if (percentage >= 0.1) return "🌱 Getting started...";
    return "🎯 Ready to begin!";
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 0.8) return Colors.green;
    if (percentage >= 0.6) return Colors.blue;
    if (percentage >= 0.4) return Colors.orange;
    return Colors.red;
  }

  String _getProgressEmoji(double percentage) {
    if (percentage >= 0.9) return "🏆";
    if (percentage >= 0.7) return "🚀";
    if (percentage >= 0.5) return "💪";
    if (percentage >= 0.3) return "📈";
    return "🎯";
  }

  Widget _buildIntelligentProgressGrid(BuildContext context, ThemeData theme, Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildIntelligentProgressCard(
            context,
            theme,
            "📖 Theory Intelligence",
            stats['completedOverallTheory'] as int,
            stats['totalOverallTheory'] as int,
            stats['theoryProgress'] as double,
            Colors.blue,
            _getTheoryInsight(stats['theoryProgress'] as double),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildIntelligentProgressCard(
            context,
            theme,
            "🔬 Practical Intelligence",
            stats['completedOverallPractical'] as int,
            stats['totalOverallPractical'] as int,
            stats['practicalProgress'] as double,
            Colors.orange,
            _getPracticalInsight(stats['practicalProgress'] as double),
          ),
        ),
      ],
    );
  }

  Widget _buildIntelligentProgressCard(
    BuildContext context,
    ThemeData theme,
    String title,
    int completed,
    int total,
    double progress,
    Color color,
    String insight,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  title.contains('Theory') ? Icons.menu_book : Icons.science,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$completed',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                ' / $total',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'completed',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              widthFactor: progress,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}% • $insight',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getTheoryInsight(double progress) {
    if (progress >= 0.8) return "Theory mastery";
    if (progress >= 0.6) return "Strong foundation";
    if (progress >= 0.4) return "Building knowledge";
    return "Focus needed";
  }

  String _getPracticalInsight(double progress) {
    if (progress >= 0.8) return "Hands-on expert";
    if (progress >= 0.6) return "Good application";
    if (progress >= 0.4) return "Gaining experience";
    return "Practice more";
  }

  Widget _buildIntelligentSubjectTile(BuildContext context, ThemeData theme, Map<String, dynamic> subjectData, int index) {
    final progress = subjectData['progress'] as double;
    final velocity = _learningVelocity[subjectData['name']] ?? 0.5;
    final Color progressColor = _getProgressColor(progress);
    
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, animationValue, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue.clamp(0.0, 1.0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    progressColor.withOpacity(0.1),
                    progressColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: progressColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subjectData['name'] as String,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${subjectData['completed']} of ${subjectData['total']} units • ${_getVelocityDescription(velocity)}",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: progressColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${(progress * 100).toInt()}%",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: progressColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _getVelocityColor(velocity).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getVelocityIcon(velocity),
                              size: 16,
                              color: _getVelocityColor(velocity),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: progressColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [progressColor, progressColor.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getSubjectInsight(progress, velocity),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: progressColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Velocity: ${(velocity * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getVelocityColor(velocity),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getVelocityColor(double velocity) {
    if (velocity > 0.7) return Colors.green;
    if (velocity > 0.4) return Colors.orange;
    return Colors.red;
  }

  IconData _getVelocityIcon(double velocity) {
    if (velocity > 0.7) return Icons.rocket_launch;
    if (velocity > 0.4) return Icons.directions_walk;
    return Icons.warning;
  }

  String _getSubjectInsight(double progress, double velocity) {
    if (progress >= 0.8 && velocity > 0.6) return "🏆 Mastery achieved";
    if (progress >= 0.6 && velocity > 0.5) return "🚀 Excellent pace";
    if (progress >= 0.4) return "📈 Good progress";
    if (velocity < 0.3) return "⚠️ Needs attention";
    return "🎯 Building momentum";
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
