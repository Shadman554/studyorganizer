
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

class StudyTimerPage extends StatefulWidget {
  @override
  _StudyTimerPageState createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage> 
    with TickerProviderStateMixin {
  int _hours = 0;
  int _minutes = 25;
  int _seconds = 0;
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  List<Map<String, dynamic>> _sessionHistory = [];
  int _totalSeconds = 0;
  int _originalTotalSeconds = 0;

  double get progress => _originalTotalSeconds > 0 && _totalSeconds >= 0 
      ? (1 - (_totalSeconds / _originalTotalSeconds)).clamp(0.0, 1.0) 
      : 0.0;
  int _streakCount = 0;
  int _totalStudyTime = 0; // in minutes

  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _buttonController;
  late AnimationController _glowController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _rippleAnimation;

  final List<Map<String, dynamic>> _quickTimePresets = [
    {'minutes': 15, 'label': '15 min', 'icon': Icons.coffee, 'color': Colors.brown},
    {'minutes': 25, 'label': '25 min', 'icon': Icons.school, 'color': Colors.orange},
    {'minutes': 30, 'label': '30 min', 'icon': Icons.book, 'color': Colors.blue},
    {'minutes': 45, 'label': '45 min', 'icon': Icons.psychology, 'color': Colors.purple},
    {'minutes': 60, 'label': '1 hour', 'icon': Icons.schedule, 'color': Colors.green},
    {'minutes': 90, 'label': '90 min', 'icon': Icons.fitness_center, 'color': Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    _totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;
    _originalTotalSeconds = _totalSeconds;

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _pulseController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
  }

  void startTimer() {
    if (!_isRunning) {
      if (!_isPaused) {
        _totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;
        _originalTotalSeconds = _totalSeconds;
      }

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_totalSeconds > 0) {
            _totalSeconds--;
            _hours = _totalSeconds ~/ 3600;
            _minutes = (_totalSeconds % 3600) ~/ 60;
            _seconds = _totalSeconds % 60;

            final progress = _originalTotalSeconds > 0 
                ? 1 - (_totalSeconds / _originalTotalSeconds) 
                : 0.0;
            _progressController.animateTo(progress);
          } else {
            _timer?.cancel();
            _isRunning = false;
            _isPaused = false;
            _showCompletionDialog();
            _pulseController.repeat(reverse: true);
            _glowController.repeat(reverse: true);
          }
        });
      });

      setState(() {
        _isRunning = true;
        _isPaused = false;
      });

      _pulseController.stop();
      _pulseController.value = 1.0;
      _glowController.stop();
      _glowController.value = 0.8;

      // Haptic feedback
      HapticFeedback.lightImpact();
      _rippleController.forward().then((_) => _rippleController.reset());
    }
  }

  void pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
    _pulseController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
    HapticFeedback.lightImpact();
  }

  void resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _hours = 0;
      _minutes = 25;
      _seconds = 0;
      _totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;
      _originalTotalSeconds = _totalSeconds;
    });
    _progressController.reset();
    _pulseController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
    HapticFeedback.mediumImpact();
  }

  void _setQuickTime(int minutes) {
    if (_isRunning) return;

    setState(() {
      _hours = minutes ~/ 60;
      _minutes = minutes % 60;
      _seconds = 0;
      _totalSeconds = _hours * 3600 + _minutes * 60;
      _originalTotalSeconds = _totalSeconds;
      _isPaused = false;
    });
    _progressController.reset();
    HapticFeedback.selectionClick();
  }

  void _showCompletionDialog() {
    final completedMinutes = _originalTotalSeconds ~/ 60;
    final session = {
      'duration': completedMinutes,
      'timestamp': DateTime.now(),
      'type': _getSessionType(completedMinutes),
    };

    setState(() {
      _sessionHistory.insert(0, session);
      if (_sessionHistory.length > 10) {
        _sessionHistory.removeLast();
      }
      _streakCount++;
      _totalStudyTime += completedMinutes;
    });

    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 20,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                Colors.white,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.green, Colors.green.shade300],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            blurRadius: 25,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.celebration,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                '🎉 Session Complete!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  'You studied for $completedMinutes minutes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('Streak', '$_streakCount', Icons.local_fire_department, Colors.orange),
                  _buildStatCard('Total', '${_totalStudyTime}m', Icons.schedule, Colors.blue),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _getMotivationalMessage(completedMinutes),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showHistoryBottomSheet(context);
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('View History'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        resetTimer();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('New Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                      ),
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
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
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _getSessionType(int minutes) {
    if (minutes >= 90) return 'Deep Focus';
    if (minutes >= 60) return 'Long Study';
    if (minutes >= 45) return 'Study Block';
    if (minutes >= 25) return 'Pomodoro';
    return 'Quick Session';
  }

  String _getMotivationalMessage(int minutes) {
    if (minutes >= 90) return 'Outstanding dedication! You\'re building incredible focus! 🔥';
    if (minutes >= 60) return 'Excellent work! Your consistency is paying off! 💪';
    if (minutes >= 45) return 'Great job! You\'re developing strong study habits! ⭐';
    if (minutes >= 25) return 'Perfect! Every focused minute makes a difference! 📚';
    return 'Good start! Small steps lead to big achievements! 🌟';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _originalTotalSeconds > 0 && _totalSeconds >= 0
        ? (1 - (_totalSeconds / _originalTotalSeconds)).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildEnhancedAppBar(theme),
              _buildStatsBar(theme),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildEnhancedTimerRing(theme, progress),
                      const SizedBox(height: 50),
                      _buildEnhancedControlButtons(theme),
                    ],
                  ),
                ),
              ),
              _buildEnhancedQuickPresets(theme),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedAppBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.8),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Study Timer',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (_streakCount > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '$_streakCount streak',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => _showHistoryBottomSheet(context),
              icon: Icon(
                Icons.history_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Sessions', '${_sessionHistory.length}', Icons.timer, theme),
          Container(width: 1, height: 30, color: theme.dividerColor),
          _buildStatItem('Total Time', '${_totalStudyTime}m', Icons.schedule, theme),
          Container(width: 1, height: 30, color: theme.dividerColor),
          _buildStatItem('Today', '${_getTodayMinutes()}m', Icons.today, theme),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  int _getTodayMinutes() {
    final today = DateTime.now();
    return _sessionHistory
        .where((session) {
          final sessionDate = session['timestamp'] as DateTime;
          return sessionDate.day == today.day &&
                 sessionDate.month == today.month &&
                 sessionDate.year == today.year;
        })
        .fold(0, (sum, session) => sum + (session['duration'] as int));
  }

  Widget _buildEnhancedTimerRing(ThemeData theme, double progress) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _glowAnimation, _rippleAnimation]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Ripple effect
            if (_rippleAnimation.value > 0)
              Container(
                width: 320 + (_rippleAnimation.value * 100),
                height: 320 + (_rippleAnimation.value * 100),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(1 - _rippleAnimation.value),
                    width: 2,
                  ),
                ),
              ),

            // Main timer ring
            Transform.scale(
              scale: _isRunning ? 1.0 : _pulseAnimation.value,
              child: GestureDetector(
                onTap: _isRunning ? null : () => _showTimePickerSheet(context),
                child: Container(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow ring
                      Container(
                        width: 340,
                        height: 340,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(_isRunning ? _glowAnimation.value * 0.3 : 0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),

                      // Main ring background
                      Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.surface,
                              theme.colorScheme.surface.withOpacity(0.8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                      ),

                      // Progress ring
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(280, 280),
                            painter: EnhancedProgressRingPainter(
                              progress: _progressAnimation.value,
                              primaryColor: theme.colorScheme.primary,
                              backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
                              isRunning: _isRunning,
                            ),
                          );
                        },
                      ),

                      // Inner content
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.surface,
                              theme.colorScheme.surface.withOpacity(0.9),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 1,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: _buildTimerContent(theme),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimerContent(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Main time display
        TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 1.0, end: _isRunning ? 1.1 : 1.0),
          builder: (context, double scale, child) {
            return Transform.scale(
              scale: scale,
              child: Text(
                '${_hours.toString().padLeft(2, '0')}:${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // Status indicator
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _getStatusColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getStatusColor().withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isRunning) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                _getStatusIcon(),
                size: 16,
                color: _getStatusColor(),
              ),
              const SizedBox(width: 6),
              Text(
                _getStatusText(),
                style: TextStyle(
                  color: _getStatusColor(),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Progress percentage
        if (_isRunning && _originalTotalSeconds > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${(progress * 100).toInt()}% Complete',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Color _getStatusColor() {
    if (_isRunning) return Colors.green;
    if (_isPaused) return Colors.orange;
    return Theme.of(context).colorScheme.primary;
  }

  IconData _getStatusIcon() {
    if (_isRunning) return Icons.play_arrow;
    if (_isPaused) return Icons.pause;
    return Icons.touch_app;
  }

  String _getStatusText() {
    if (_isRunning) return 'In Progress';
    if (_isPaused) return 'Paused';
    return 'Tap to set time';
  }

  Widget _buildEnhancedControlButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: _isRunning ? Colors.orange : Colors.green,
          onPressed: _isRunning ? pauseTimer : startTimer,
          size: 80,
          isPrimary: true,
          label: _isRunning ? 'Pause' : (_isPaused ? 'Resume' : 'Start'),
        ),
        const SizedBox(width: 32),
        _buildControlButton(
          icon: Icons.stop_rounded,
          color: Colors.red,
          onPressed: resetTimer,
          size: 64,
          label: 'Reset',
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required double size,
    required String label,
    bool isPrimary = false,
  }) {
    return AnimatedBuilder(
      animation: _buttonScaleAnimation,
      builder: (context, child) {
        return Column(
          children: [
            Transform.scale(
              scale: isPrimary ? _buttonScaleAnimation.value : 1.0,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,
                      color.withOpacity(0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: isPrimary ? 25 : 15,
                      spreadRadius: isPrimary ? 3 : 1,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (isPrimary) {
                        _buttonController.forward().then((_) {
                          _buttonController.reverse();
                        });
                      }
                      onPressed();
                    },
                    borderRadius: BorderRadius.circular(size / 2),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: size * 0.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEnhancedQuickPresets(ThemeData theme) {
    return Container(
      height: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Quick Start',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickTimePresets.length,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemBuilder: (context, index) {
                final preset = _quickTimePresets[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildQuickTimeButton(
                    preset['minutes'],
                    preset['label'],
                    preset['icon'],
                    preset['color'],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTimeButton(int minutes, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isSelected = !_isRunning && !_isPaused && 
        (_hours * 60 + _minutes) == minutes;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: isSelected 
            ? color.withOpacity(0.2)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        elevation: isSelected ? 8 : 3,
        shadowColor: isSelected ? color.withOpacity(0.4) : Colors.black26,
        child: InkWell(
          onTap: () => _setQuickTime(minutes),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 90,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: isSelected 
                  ? Border.all(color: color, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? color.withOpacity(0.2)
                        : color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? color : color.withOpacity(0.7),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected 
                        ? color
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTimePickerSheet(BuildContext context) {
    final theme = Theme.of(context);
    int tempHours = _hours;
    int tempMinutes = _minutes;
    int tempSeconds = _seconds;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Set Timer Duration',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTimeWheel('Hours', tempHours, (value) {
                    tempHours = value;
                  }, 23),
                  Container(
                    width: 2,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  _buildTimeWheel('Minutes', tempMinutes, (value) {
                    tempMinutes = value;
                  }, 59),
                  Container(
                    width: 2,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  _buildTimeWheel('Seconds', tempSeconds, (value) {
                    tempSeconds = value;
                  }, 59),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hours = tempHours;
                          _minutes = tempMinutes;
                          _seconds = tempSeconds;
                          _totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;
                          _originalTotalSeconds = _totalSeconds;
                          _isPaused = false;
                        });
                        _progressController.reset();
                        Navigator.pop(context);
                        HapticFeedback.mediumImpact();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                      ),
                      child: const Text(
                        'Set Timer',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
  }

  Widget _buildTimeWheel(String label, int value, Function(int) onChanged, int maxValue) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 140,
          width: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surface,
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListWheelScrollView.useDelegate(
            itemExtent: 40,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < 0 || index > maxValue) return null;

                return Container(
                  alignment: Alignment.center,
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: value == index ? FontWeight.bold : FontWeight.normal,
                      color: value == index 
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                );
              },
              childCount: maxValue + 1,
            ),
            onSelectedItemChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _showHistoryBottomSheet(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session History',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            '${_sessionHistory.length} sessions completed',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_sessionHistory.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _sessionHistory.clear();
                          _streakCount = 0;
                          _totalStudyTime = 0;
                        });
                        Navigator.pop(context);
                        HapticFeedback.lightImpact();
                      },
                      icon: const Icon(Icons.clear_all_rounded),
                      label: const Text('Clear All'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _sessionHistory.isEmpty
                  ? _buildEmptyHistoryState(theme)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _sessionHistory.length,
                      itemBuilder: (context, index) {
                        final session = _sessionHistory[index];
                        final duration = session['duration'] as int;
                        final timestamp = session['timestamp'] as DateTime;
                        final type = session['type'] as String;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    _getSessionColor(type),
                                    _getSessionColor(type).withOpacity(0.7),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getSessionColor(type).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _getSessionIcon(type),
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              type,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${_formatDate(timestamp)} • $duration minutes',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _getSessionColor(type).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getSessionColor(type).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '${duration}m',
                                style: TextStyle(
                                  color: _getSessionColor(type),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.secondary.withOpacity(0.1),
                ],
              ),
            ),
            child: Icon(
              Icons.schedule_rounded,
              size: 60,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No sessions yet',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start your first study session to\nbegin tracking your progress!',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.outline,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getSessionColor(String type) {
    switch (type) {
      case 'Deep Focus': return Colors.purple;
      case 'Long Study': return Colors.blue;
      case 'Study Block': return Colors.green;
      case 'Pomodoro': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getSessionIcon(String type) {
    switch (type) {
      case 'Deep Focus': return Icons.psychology_rounded;
      case 'Long Study': return Icons.school_rounded;
      case 'Study Block': return Icons.book_rounded;
      case 'Pomodoro': return Icons.timer_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (sessionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _progressController.dispose();
    _buttonController.dispose();
    _glowController.dispose();
    _rippleController.dispose();
    super.dispose();
  }
}

class EnhancedProgressRingPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color backgroundColor;
  final bool isRunning;

  EnhancedProgressRingPainter({
    required this.progress,
    required this.primaryColor,
    required this.backgroundColor,
    required this.isRunning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 12.0;
    
    // Ensure progress is valid
    final safeProgress = progress.isNaN || progress.isInfinite 
        ? 0.0 
        : progress.clamp(0.0, 1.0);

    // Background ring
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (radius - strokeWidth / 2 > 0) {
      canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);
    }

    // Only draw progress if there's actual progress
    if (safeProgress > 0) {
      // Progress ring with gradient
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + (2 * math.pi * safeProgress),
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.8),
            primaryColor,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * safeProgress;
      
      // Ensure sweep angle is valid
      if (sweepAngle > 0 && sweepAngle.isFinite) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
          -math.pi / 2,
          sweepAngle,
          false,
          progressPaint,
        );

        // Glowing effect when running
        if (isRunning) {
          final glowPaint = Paint()
            ..color = primaryColor.withOpacity(0.3)
            ..strokeWidth = strokeWidth + 6
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
            -math.pi / 2,
            sweepAngle,
            false,
            glowPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
