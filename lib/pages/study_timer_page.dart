import 'package:flutter/material.dart';
import 'dart:async';

class StudyTimerPage extends StatefulWidget {
  @override
  _StudyTimerPageState createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage> with SingleTickerProviderStateMixin {
  int _hours = 0;
  int _minutes = 25;
  int _seconds = 0;
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  List<String> _sessionHistory = [];
  int _totalSeconds = 0;
  late AnimationController _animationController;
  
  final List<int> _quickTimePresets = [15, 25, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    _totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
  }

  void startTimer() {
    if (!_isRunning) {
      if (!_isPaused) {
        _totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;
      }
      
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          if (_totalSeconds > 0) {
            _totalSeconds--;
            _hours = _totalSeconds ~/ 3600;
            _minutes = (_totalSeconds % 3600) ~/ 60;
            _seconds = _totalSeconds % 60;
            _animationController.value = _totalSeconds / (_hours * 3600 + _minutes * 60 + _seconds);
          } else {
            _timer?.cancel();
            _isRunning = false;
            _isPaused = false;
            _showCompletionDialog();
          }
        });
      });
      
      setState(() {
        _isRunning = true;
        _isPaused = false;
      });
    }
  }

  void pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
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
    });
  }

  void _setQuickTime(int minutes) {
    setState(() {
      _hours = minutes ~/ 60;
      _minutes = minutes % 60;
      _seconds = 0;
      _totalSeconds = _hours * 3600 + _minutes * 60;
    });
  }

  void _showCompletionDialog() {
    String sessionDuration = '${_hours}h ${_minutes}m ${_seconds}s';
    _sessionHistory.add('Session completed: $sessionDuration');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber),
            SizedBox(width: 10),
            Text('Great Job!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(0.1),
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Study session completed!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'You studied for $sessionDuration',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              resetTimer();
            },
            child: Text('Start New Session'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Study Timer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
            onPressed: () => _showHistoryBottomSheet(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Design
          Positioned.fill(
            child: CustomPaint(
              painter: CircleBackgroundPainter(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            children: [
              // Timer Section
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Progress Ring
                    GestureDetector(
                      onTap: _isRunning ? null : () => _showTimePickerSheet(context),
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Timer Display
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${_hours.toString().padLeft(2, '0')}:${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                                if (!_isRunning)
                                  Text(
                                    'Tap to set time',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    // Control Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildControlButton(
                          icon: _isRunning ? Icons.pause : Icons.play_arrow,
                          color: _isRunning ? Colors.orange : Colors.green,
                          onPressed: _isRunning ? pauseTimer : startTimer,
                          size: 72,
                        ),
                        SizedBox(width: 24),
                        _buildControlButton(
                          icon: Icons.stop,
                          color: Colors.red,
                          onPressed: resetTimer,
                          size: 56,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Quick Presets
              Container(
                margin: EdgeInsets.symmetric(vertical: 20),
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickTimePresets.length,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: _buildQuickTimeButton(_quickTimePresets[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required double size,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: color,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTimeButton(int minutes) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.1),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: () => _setQuickTime(minutes),
        child: Text(
          '$minutes min',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showTimePickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set Timer Duration',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTimeWheel('Hours', _hours, (value) {
                  setState(() => _hours = value);
                }, 23),
                _buildTimeWheel('Minutes', _minutes, (value) {
                  setState(() => _minutes = value);
                }, 59),
                _buildTimeWheel('Seconds', _seconds, (value) {
                  setState(() => _seconds = value);
                }, 59),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;
                });
                Navigator.pop(context);
              },
              child: Text('Set Timer'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeWheel(String label, int value, Function(int) onChanged, int maxValue) {
    return Column(
      children: [
        Text(label),
        Container(
          height: 100,
          width: 60,
          child: ListWheelScrollView(
            itemExtent: 40,
            diameterRatio: 1.5,
            physics: FixedExtentScrollPhysics(),
            children: List.generate(maxValue + 1, (index) {
              return Center(
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: value == index ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }),
            onSelectedItemChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _showHistoryBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Session History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _sessionHistory.clear();
                      });
                      Navigator.pop(context);
                    },
                    child: Text('Clear All'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _sessionHistory.isEmpty
                  ? Center(
                      child: Text(
                        'No sessions yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _sessionHistory.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: CircleAvatar(
                            child: Icon(Icons.timer),
                          ),
                          title: Text(_sessionHistory[index]),
                          subtitle: Text('Session ${index + 1}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
}

class CircleBackgroundPainter extends CustomPainter {
  final Color color;

  CircleBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(0, size.height * 0.2),
      size.width * 0.5,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width, size.height * 0.8),
      size.width * 0.4,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
} 