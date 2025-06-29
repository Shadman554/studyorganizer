import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math; // Import math for pi

// --- Flashcard Model ---
class Flashcard {
  final String id;
  String question;
  String answer;
  String category; // Lecture name
  String? pdfName; // PDF file name
  bool isLearned;

  Flashcard({
    required this.question,
    required this.answer,
    required this.category,
    this.pdfName,
    this.isLearned = false,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'answer': answer,
        'category': category,
        'pdfName': pdfName,
        'isLearned': isLearned,
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        id: json['id'],
        question: json['question'],
        answer: json['answer'],
        category: json['category'],
        pdfName: json['pdfName'],
        isLearned: json['isLearned'] ?? false,
      );
}

// --- Main Flashcards Page ---
class FlashcardsPage extends StatefulWidget {
  final List<Map<String, String>>? flashcards; // AI-generated flashcards
  final String? title; // Optional title for the page
  final String? lectureId; // ID of the lecture these flashcards belong to

  const FlashcardsPage({
    super.key,
    this.flashcards,
    this.title,
    this.lectureId,
  });

  @override
  _FlashcardsPageState createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends State<FlashcardsPage>
    with SingleTickerProviderStateMixin {
  List<Flashcard> _masterFlashcards = []; // Original list from storage
  List<Flashcard> _sessionFlashcards =
      []; // For current viewing/shuffling session
  List<String> _categories = [];
  String? _selectedCategory;
  bool _showAnswer = false;
  int _currentIndex = 0;
  bool _isShuffled = false; // Tracks if the current session is shuffled

  late AnimationController _animationController;
  late Animation<double> _animation;
  late String _storageKey;

  // Get storage key based on lecture ID if available
  String _getStorageKey() {
    if (widget.lectureId != null) {
      return 'flashcards_${widget.lectureId}';
    }
    return 'flashcards'; // Fallback to general storage
  }

  // Reset the session display with optional shuffling
  void _resetSessionDisplay({bool shuffle = false}) {
    final filtered = _getFilteredCardsFromMaster();
    setState(() {
      _sessionFlashcards = List.from(filtered);
      if (shuffle && _sessionFlashcards.isNotEmpty) {
        _sessionFlashcards.shuffle();
        _isShuffled = true;
      } else {
        _isShuffled = false; // Reset if not shuffling or list is empty
      }
      _currentIndex = 0;
      _showAnswer = false;
      _animationController.reset();
    });
  }

  @override
  void initState() {
    super.initState();
    // Initialize storage key
    _storageKey = _getStorageKey();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400), // Slightly faster
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));

    // First load existing flashcards
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFlashcards().then((_) {
       // --- Inside initState, after _loadFlashcards().then((_) { ---
if (widget.flashcards != null && widget.flashcards!.isNotEmpty) {
  // Determine the category for AI-generated cards
  String aiCategory = widget.title ?? 'AI Generated';
  if (aiCategory.trim().isEmpty) { // Check if widget.title was blank
    aiCategory = 'AI Generated'; // Fallback to 'AI Generated'
  }

  final aiCards = widget.flashcards!.map((card) => Flashcard(
    question: card['front'] ?? '',
    answer: card['back'] ?? '',
    category: aiCategory, // Use the sanitized category
    pdfName: card['pdfName'],
  )).toList();

  setState(() {
    _masterFlashcards.addAll(aiCards);
    _updateCategories(); // This will now use the potentially corrected aiCategory
  });
  _saveFlashcards().then((_) {
    setState(() {
      // Use the same sanitized category for selecting the filter
      _selectedCategory = aiCategory;
    });
    _resetSessionDisplay();
  });
}

      });
    });
  }


  Future<void> _loadFlashcards() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get all keys that might contain flashcards
    final allKeys = prefs.getKeys().where((key) => key.startsWith('flashcards')).toList();
    
    // Load flashcards from all keys
    List<Flashcard> allFlashcards = [];
    
    for (final key in allKeys) {
      final cardsJson = prefs.getString(key);
      if (cardsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cardsJson);
          final cards = decoded.map((item) => Flashcard.fromJson(item)).toList();
          allFlashcards.addAll(cards);
        } catch (e) {
          //print('Error loading flashcards from $key: $e');
        }
      }
    }
    
    setState(() {
      _masterFlashcards = allFlashcards;
      _updateCategories();
    });
    
    // Ensure we update the session flashcards after loading from storage
    _resetSessionDisplay(shuffle: _isShuffled);
  }

  Future<void> _saveFlashcards() async {
    final prefs = await SharedPreferences.getInstance();
    // Save the master list, not the potentially shuffled session list
    final encoded =
        jsonEncode(_masterFlashcards.map((e) => e.toJson()).toList());
    
    // Save to the current storage key
    await prefs.setString(_storageKey, encoded);
    
    // For backward compatibility, also save to 'flashcards' general key
    if (_storageKey != 'flashcards') {
      await prefs.setString('flashcards', encoded);
    }
  }

  void _updateCategories() {
    // No setState needed if called from contexts that already setState (like _loadFlashcards via _resetSessionDisplay)
    // Get all unique categories (lecture names)
    _categories = _masterFlashcards.map((card) => card.category).toSet().toList()..sort();
    
    // Also add PDF names to the categories list if they exist
    final pdfNames = _masterFlashcards
        .where((card) => card.pdfName != null)
        .map((card) => card.pdfName!)
        .toSet()
        .toList();
    
    // Add PDF names to categories if they're not already there
    for (var pdfName in pdfNames) {
      if (!_categories.contains(pdfName)) {
        _categories.add(pdfName);
      }
    }
    
    // Sort the final list
    _categories.sort();
  }

  List<Flashcard> _getFilteredCardsFromMaster() {
    if (_selectedCategory == null) return _masterFlashcards;
    
    return _masterFlashcards.where((card) => 
      // Match if the selected category is the card's category
      card.category == _selectedCategory ||
      // OR match if the selected category is the card's PDF name
      (card.pdfName != null && card.pdfName == _selectedCategory)
    ).toList();
  }

  void _toggleShuffle() {
    if (_masterFlashcards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No flashcards available to shuffle.'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    _resetSessionDisplay(shuffle: !_isShuffled); // Toggle current shuffle state
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(_isShuffled ? 'Cards shuffled!' : 'Shuffle turned off.'),
          duration: const Duration(seconds: 1)),
    );
  }

  void _addFlashcard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddFlashcardSheet(
        categories: _categories,
        onAdd: (question, answer, category, pdfName) {
          final newCard = Flashcard(
            question: question,
            answer: answer,
            category: category,
            pdfName: pdfName,
          );
          setState(() {
            _masterFlashcards.add(newCard);
            _updateCategories();
            // After adding, reset session to include the new card, possibly filtering to its category
            // If PDF name is provided, select it as the filter, otherwise use category
            _selectedCategory = pdfName ?? category;
            _resetSessionDisplay(shuffle: _isShuffled); // Maintain shuffle state or default
            // Try to find the new card in the session list to set as current
            _currentIndex = _sessionFlashcards.indexWhere((card) => card.id == newCard.id);
            if (_currentIndex == -1) {
              _currentIndex = _sessionFlashcards.isNotEmpty ? _sessionFlashcards.length - 1 : 0;
            }
          });
          _saveFlashcards();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Flashcard added successfully!'),
                backgroundColor: Colors.green),
          );
        },
      ),
    );
  }

  void _manageFlashcards() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageFlashcardsPage(
          flashcards: List.from(_masterFlashcards), // Pass a copy
          lectureId: widget.lectureId,
          title: widget.lectureId != null ? _selectedCategory : null, // Pass the selected category as title
          onUpdate: (updatedList) {
            // This list comes from ManageFlashcardsPage
            setState(() {
              _masterFlashcards = updatedList;
              _updateCategories();
              _resetSessionDisplay(
                  shuffle: _isShuffled); // Refresh current view
            });
            _saveFlashcards();
          },
        ),
      ),
    );
  }

  void _toggleAnswer() {
    if (_sessionFlashcards.isEmpty) return;
    if (_animationController.isCompleted || _animationController.isDismissed) {
      setState(() {
        _showAnswer = !_showAnswer;
      });
      if (_showAnswer) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _nextCard() {
    if (_sessionFlashcards.isEmpty) return;
    if (_currentIndex < _sessionFlashcards.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
      _animationController.reset();
    }
  }

  void _previousCard() {
    if (_sessionFlashcards.isEmpty) return;
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showAnswer = false;
      });
      _animationController.reset();
    }
  }

  // --- UI Builder Methods ---

  Widget _buildCardFace(Flashcard card, bool isFrontSide) {
    final title = isFrontSide ? 'Question' : 'Answer';
    final content = isFrontSide ? card.question : card.answer;
    final category = card.category;
    final theme = Theme.of(context);

    // Define card background and text colors based on theme
    Color cardBackgroundColor;
    Color primaryTextColor;
    Color secondaryTextColor;
    Color chipBackgroundColor;
    Color chipLabelColor;
    Color titleColor;

    if (theme.brightness == Brightness.dark) {
      // Dark Mode Colors
      cardBackgroundColor =
          theme.colorScheme.surface; // A slightly elevated surface
      primaryTextColor = theme.colorScheme.onSurface;
      secondaryTextColor = theme.colorScheme.onSurface.withOpacity(0.7);
      chipBackgroundColor = theme.colorScheme.primary.withOpacity(0.2);
      chipLabelColor = theme.colorScheme.primary;
      titleColor = theme.colorScheme.primary;
    } else {
      // Light Mode Colors
      cardBackgroundColor =
          theme.colorScheme.surface; // Usually white or very light gray
      primaryTextColor =
          theme.colorScheme.onSurface; // Usually dark gray or black
      secondaryTextColor = theme.colorScheme.onSurface.withOpacity(0.6);
      chipBackgroundColor = theme.colorScheme.primary.withOpacity(0.1);
      chipLabelColor = theme.colorScheme.primary;
      titleColor = theme.colorScheme.primary;
    }

    // The outer Card in _buildFlashcard provides elevation and main shape.
    // This Card is for content styling.
    return Card(
      elevation: 0, // No separate elevation, outer card handles it.
      margin: EdgeInsets.zero, // No margin, outer card handles spacing if any.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
            19), // Slightly less to see outer card border if any
      ),
      clipBehavior: Clip.antiAlias,
      color: cardBackgroundColor, // Apply themed background color
      child: Container(
        padding: const EdgeInsets.all(20), // Adjusted padding
        width: double.infinity,
        // Removed the heavy top border for a cleaner look.
        // Using subtle border for definition.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19), // Match card shape
          border: Border.all(
            color: theme.colorScheme.outline
                .withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.4),
            width: 1, // Subtle border
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Chip(
                  label: Text(category,
                      style: TextStyle(
                          color: chipLabelColor, fontWeight: FontWeight.w500)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: chipBackgroundColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: chipLabelColor.withOpacity(0.5))),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    content,
                    style: theme.textTheme.headlineMedium?.copyWith(
                        // Slightly larger text for content
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        color: primaryTextColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 8.0), // Add some space above hint
                child: Text(
                  'Tap to flip / Swipe to navigate',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondaryTextColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashcard(Flashcard card) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final angle = _animation.value * math.pi;
        final showBack = _animation.value > 0.5;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          alignment: Alignment.center,
          child: showBack
              ? Transform(
                  transform: Matrix4.identity()..rotateY(math.pi),
                  alignment: Alignment.center,
                  child: _buildCardFace(card, false),
                )
              : _buildCardFace(card, true),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined,
                size: 100, color: theme.hintColor.withOpacity(0.6)),
            const SizedBox(height: 24),
            Text(
              _selectedCategory == null
                  ? 'No Flashcards Yet!'
                  : 'No Flashcards in "$_selectedCategory"',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: theme.hintColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add Card" to create your first one.',
              style:
                  theme.textTheme.titleMedium?.copyWith(color: theme.hintColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(
      IconData icon, VoidCallback? onPressed, String tooltip) {
    return IconButton.filledTonal(
      // Using filled tonal for better theming
      icon: Icon(icon),
      onPressed: onPressed,
      iconSize: 28, // Slightly smaller for balance
      padding: const EdgeInsets.all(14), // Adjusted padding
      tooltip: tooltip,
      style: IconButton.styleFrom(
        disabledBackgroundColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
        disabledForegroundColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
      ),
    );
  }

  Widget _buildFlashcardView() {
    if (_sessionFlashcards.isEmpty)
      return _buildEmptyState(); // Should not happen if master list is not empty

    final currentCard = _sessionFlashcards[_currentIndex];
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _toggleAnswer,
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 100) {
                // Increased sensitivity
                _previousCard();
              } else if (details.primaryVelocity! < -100) {
                _nextCard();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(
                  20), // Slightly reduced main card padding
              child: _buildFlashcard(currentCard),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            '${_currentIndex + 1} / ${_sessionFlashcards.length}',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween, // Use spaceBetween
            children: [
              _buildNavButton(Icons.arrow_back_ios_new_rounded,
                  _currentIndex > 0 ? _previousCard : null, "Previous Card"),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    currentCard.isLearned = !currentCard.isLearned;
                    // Update in master list as well
                    final masterIndex = _masterFlashcards
                        .indexWhere((fc) => fc.id == currentCard.id);
                    if (masterIndex != -1) {
                      _masterFlashcards[masterIndex].isLearned =
                          currentCard.isLearned;
                    }
                  });
                  _saveFlashcards();
                },
                icon: Icon(
                  currentCard.isLearned
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                  color: currentCard.isLearned
                      ? Colors.green
                      : theme.colorScheme.primary,
                ),
                label: Text(currentCard.isLearned ? 'Learned!' : 'Mark Learned',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: currentCard.isLearned
                            ? Colors.green
                            : theme.colorScheme.primary.withOpacity(0.7),
                        width: 1.5),
                    foregroundColor: currentCard.isLearned
                        ? Colors.green
                        : theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
              _buildNavButton(
                  Icons.arrow_forward_ios_rounded,
                  _currentIndex < _sessionFlashcards.length - 1
                      ? _nextCard
                      : null,
                  "Next Card"),
            ],
          ),
        ),
        const SizedBox(height: 60), // Space for FAB
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        actions: [
          IconButton(
            icon: Icon(
                _isShuffled
                    ? Icons.shuffle_on_outlined
                    : Icons.shuffle_outlined,
                color: _isShuffled ? theme.colorScheme.primary : null),
            tooltip: _isShuffled ? "Turn Off Shuffle" : "Shuffle Cards",
            onPressed: _toggleShuffle,
          ),
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list_alt), // Changed icon slightly
            tooltip: "Filter by Category",
            onSelected: (category) {
              setState(() {
                _selectedCategory = category;
              });
              _resetSessionDisplay(
                  shuffle: _isShuffled); // Apply filter and maintain shuffle
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: null,
                child: Text('All Categories',
                    style: TextStyle(
                        fontWeight: _selectedCategory == null
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ),
              if (_categories.isNotEmpty) const PopupMenuDivider(),
              ..._categories.map((category) => PopupMenuItem(
                    value: category,
                    child: Text(category,
                        style: TextStyle(
                            fontWeight: _selectedCategory == category
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  )),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_outlined), // Changed icon slightly
            tooltip: "Manage Cards",
            onPressed: _manageFlashcards,
          ),
        ],
      ),
      body:
          _masterFlashcards.isEmpty // Check master list for initial empty state
              ? _buildEmptyState()
              : _buildFlashcardView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFlashcard,
        label: const Text('Add Card'),
        icon: const Icon(Icons.add_circle_outline_rounded),
        tooltip: 'Add New Flashcard',
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

// --- Add Flashcard Bottom Sheet ---
class _AddFlashcardSheet extends StatefulWidget {
  final List<String> categories;
  final Function(String, String, String, String?) onAdd;

  const _AddFlashcardSheet({
    required this.categories,
    required this.onAdd,
  });

  @override
  __AddFlashcardSheetState createState() => __AddFlashcardSheetState();
}

class __AddFlashcardSheetState extends State<_AddFlashcardSheet> {
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  final _newCategoryController = TextEditingController();
  final _pdfNameController = TextEditingController();
  String? _selectedExistingCategory;
  final _formKey = GlobalKey<FormState>();
  bool _useNewCategory = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inputDecoration = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:
          BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.3)),
    );
    final focusedInputDecoration = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
    );

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20, // Extra padding
        top: 20, left: 20, right: 20,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        // Moved Form to wrap SingleChildScrollView content
        key: _formKey,
        child: SingleChildScrollView(
          // Ensure content scrolls when keyboard is up
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Flashcard',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _questionController,
                decoration: InputDecoration(
                  labelText: 'Question *',
                  hintText: 'e.g., What is the powerhouse of the cell?',
                  prefixIcon: const Icon(Icons.help_outline_rounded),
                  border: inputDecoration,
                  focusedBorder: focusedInputDecoration,
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor.withOpacity(0.5),
                ),
                maxLines: 3,
                minLines: 1,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Question cannot be empty'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _answerController,
                decoration: InputDecoration(
                  labelText: 'Answer *',
                  hintText: 'e.g., Mitochondria',
                  prefixIcon: const Icon(Icons.lightbulb_outline_rounded),
                  border: inputDecoration,
                  focusedBorder: focusedInputDecoration,
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor.withOpacity(0.5),
                ),
                maxLines: 3,
                minLines: 1,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Answer cannot be empty'
                    : null,
              ),
              const SizedBox(height: 20),
              Text('Category *',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (widget.categories.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedExistingCategory,
                  decoration: InputDecoration(
                    labelText: 'Select Existing Category',
                    border: inputDecoration,
                    focusedBorder: focusedInputDecoration,
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor.withOpacity(0.5),
                    prefixIcon: const Icon(Icons.folder_open_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null, // Represents option to add new or not select
                      child: Text('-- Or Add New Below --',
                          style: TextStyle(fontStyle: FontStyle.italic)),
                    ),
                    ...widget.categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedExistingCategory = value;
                      if (value != null) {
                        _useNewCategory =
                            false; // If existing is selected, don't use new
                        _newCategoryController.clear();
                      }
                    });
                  },
                ),
              if (widget.categories.isNotEmpty) const SizedBox(height: 10),
              TextFormField(
                controller: _newCategoryController,
                decoration: InputDecoration(
                  labelText: _selectedExistingCategory == null
                      ? 'New Category Name *'
                      : 'Or Type New Category Here',
                  hintText: 'e.g., Biology Chapter 1',
                  prefixIcon: const Icon(Icons.create_new_folder_outlined),
                  border: inputDecoration,
                  focusedBorder: focusedInputDecoration,
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor.withOpacity(0.5),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _selectedExistingCategory =
                          null; // Deselect existing if typing new
                      _useNewCategory = true;
                    });
                  } else {
                    setState(() {
                      _useNewCategory = false;
                    });
                  }
                },
                validator: (value) {
                  if (_selectedExistingCategory == null &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Category is required (new or selected)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pdfNameController,
                decoration: InputDecoration(
                  labelText: 'PDF Name (Optional)',
                  hintText: 'e.g., Lecture1_PDF',
                  prefixIcon: const Icon(Icons.picture_as_pdf_outlined),
                  border: inputDecoration,
                  focusedBorder: focusedInputDecoration,
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final question = _questionController.text.trim();
                    final answer = _answerController.text.trim();
                    final String category;
                    if (_useNewCategory &&
                        _newCategoryController.text.trim().isNotEmpty) {
                      category = _newCategoryController.text.trim();
                    } else if (_selectedExistingCategory != null) {
                      category = _selectedExistingCategory!;
                    } else {
                      // This case should be caught by validator, but as a fallback
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Please select or enter a category.'),
                          backgroundColor: Colors.red));
                      return;
                    }
                    final pdfName = _pdfNameController.text.trim().isNotEmpty 
                        ? _pdfNameController.text.trim() 
                        : null;
                    widget.onAdd(question, answer, category, pdfName);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Add Flashcard',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _newCategoryController.dispose();
    _pdfNameController.dispose(); // Added dispose for pdfNameController
    super.dispose();
  }
}

// --- Manage Flashcards Page ---
class ManageFlashcardsPage extends StatefulWidget {
  final List<Flashcard> flashcards;
  final Function(List<Flashcard>) onUpdate;
  final String? lectureId; // Optional lecture ID
  final String? title; // Added title property for lecture name

  const ManageFlashcardsPage({
    super.key,
    required this.flashcards,
    required this.onUpdate,
    this.lectureId,
    this.title,
  });

  @override
  _ManageFlashcardsPageState createState() => _ManageFlashcardsPageState();
}

class _ManageFlashcardsPageState extends State<ManageFlashcardsPage> {
  late List<Flashcard> _editableFlashcards = []; // Work on a copy
  Map<String, bool> _expandedCategories = {};
  final TextEditingController _searchController = TextEditingController(); // Made final
  String _searchTerm = "";
  bool _isLoading = true;
  
  // Generate a storage key for a specific lecture or category
  String _generateStorageKey(String category) {
    return 'flashcards_${category.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}';
  }

  @override
  void initState() {
    super.initState();
    
    _loadAllFlashcards().then((_) {
      setState(() {
        _isLoading = false;
        _updateExpansionState();
      });
    });
    
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text.toLowerCase();
      });
    });
  }
  
  Future<void> _loadAllFlashcards() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    List<Flashcard> allCards = List.from(widget.flashcards); 
    
    final flashcardKeys = allKeys.where((key) => key.startsWith('flashcards')).toList();
    
    for (var key in flashcardKeys) {
      final cardsJson = prefs.getString(key);
      if (cardsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cardsJson);
          final cards = decoded.map((item) => Flashcard.fromJson(item)).toList();
          allCards.addAll(cards);
        } catch (e) {
          // Consider more robust error handling or logging
          // print('Error loading flashcards from $key: $e');
        }
      }
    }
    
    final uniqueIds = <String>{};
    allCards = allCards.where((card) => uniqueIds.add(card.id)).toList();
    
    if (mounted) { // Check if the widget is still in the tree
      setState(() {
        _editableFlashcards = allCards;
      });
    }
  }

  void _updateExpansionState() {
    final categories = _getFilteredAndGroupedCards().keys.toSet();
    Map<String, bool> newExpansionState = {};
    for (var cat in categories) { // Use for-in loop
      newExpansionState[cat] = _expandedCategories[cat] ?? false;
    }
    _expandedCategories = newExpansionState;
  }

  Future<void> _saveFlashcards() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, List<Flashcard>> groupedByStorageKey = {}; // Changed variable name for clarity
    
    for (var card in _editableFlashcards) {
      String storageKey;
      // Prioritize lectureId if available and matches the card's category for specific saving
      if (widget.lectureId != null && card.category == widget.title) { // Assuming widget.title is the lecture name for this context
         storageKey = 'flashcards_${widget.lectureId}';
      } else if (card.category.isNotEmpty) {
        storageKey = _generateStorageKey(card.category);
      } else {
        storageKey = 'flashcards'; // Fallback
      }
      
      groupedByStorageKey.putIfAbsent(storageKey, () => []).add(card);
    }
    
    // Save each group to its own storage key
    for (var entry in groupedByStorageKey.entries) {
      final encoded = jsonEncode(entry.value.map((e) => e.toJson()).toList());
      await prefs.setString(entry.key, encoded);
    }
  }

  void _deleteCard(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text(
            "Are you sure you want to delete this flashcard? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _editableFlashcards.removeWhere((card) => card.id == id);
              });
              _saveFlashcards();
              widget.onUpdate(List.from(_editableFlashcards));
              Navigator.pop(context); 
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Flashcard deleted.'),
                  backgroundColor: Colors.redAccent));
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editCard(Flashcard card) {
    final qController = TextEditingController(text: card.question);
    final aController = TextEditingController(text: card.answer);
    final cController = TextEditingController(text: card.category);
    final pController = TextEditingController(text: card.pdfName ?? '');
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);
    final inputDecoration = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:
          BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.3)),
    );
    final focusedInputDecoration = OutlineInputBorder( // Added for consistency
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Flashcard",
            style: TextStyle(color: theme.colorScheme.primary)),
        contentPadding: const EdgeInsets.all(20),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: qController,
                  decoration: InputDecoration(
                      labelText: "Question *",
                      border: inputDecoration,
                      focusedBorder: focusedInputDecoration,
                      prefixIcon: Icon(Icons.help_outline_rounded)),
                  maxLines: 3,
                  minLines: 1,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Question cannot be empty'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: aController,
                  decoration: InputDecoration(
                      labelText: "Answer *",
                      border: inputDecoration,
                      focusedBorder: focusedInputDecoration,
                      prefixIcon: Icon(Icons.lightbulb_outline_rounded)),
                  maxLines: 3,
                  minLines: 1,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Answer cannot be empty'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: cController,
                  decoration: InputDecoration(
                      labelText: "Category *", // Changed from "Lecture" for consistency
                      border: inputDecoration,
                      focusedBorder: focusedInputDecoration,
                      prefixIcon: Icon(Icons.folder_open_outlined)),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Category name cannot be empty' // Changed message
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: pController,
                  decoration: InputDecoration(
                      labelText: "PDF Name (Optional)", // Added optional
                      border: inputDecoration,
                      focusedBorder: focusedInputDecoration,
                      prefixIcon: Icon(Icons.picture_as_pdf_outlined)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  final originalCardIndex =
                      _editableFlashcards.indexWhere((fc) => fc.id == card.id);
                  if (originalCardIndex != -1) {
                    _editableFlashcards[originalCardIndex].question =
                        qController.text.trim();
                    _editableFlashcards[originalCardIndex].answer =
                        aController.text.trim();
                    _editableFlashcards[originalCardIndex].category =
                        cController.text.trim();
                    _editableFlashcards[originalCardIndex].pdfName =
                        pController.text.trim().isEmpty ? null : pController.text.trim();
                  }
                });
                _saveFlashcards();
                widget.onUpdate(List.from(_editableFlashcards));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Flashcard updated!'),
                    backgroundColor: Colors.green));
              }
            },
            child: const Text("Save Changes"),
          ),
        ],
      ),
    );
  }

  void _resetLearnedStatus() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Learned Status"),
        content: const Text(
            "Are you sure you want to mark ALL flashcards as 'Not Learned'?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                for (var card in _editableFlashcards) {
                  card.isLearned = false;
                }
              });
              _saveFlashcards();
              widget.onUpdate(List.from(_editableFlashcards));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Learned status reset for all cards.'),
                backgroundColor: Colors.blueAccent,
              ));
            },
            child: const Text("Reset All"),
          ),
        ],
      ),
    );
  }

  void _removeAllFlashcards() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion of ALL Flashcards"),
        content: const Text(
            "Are you absolutely sure you want to delete ALL flashcards? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              // Clear the in-memory list
              setState(() {
                _editableFlashcards.clear(); 
              });
              
              // Clear ALL flashcard storage keys
              final prefs = await SharedPreferences.getInstance();
              final allKeys = prefs.getKeys();
              
              // Find all keys that start with 'flashcards' and remove them
              for (final key in allKeys) {
                if (key.startsWith('flashcards')) {
                  await prefs.remove(key);
                }
              }
              
              // Update the parent widget
              widget.onUpdate(List.from(_editableFlashcards));
              
              // Navigate back
              Navigator.pop(context); 
              if (Navigator.canPop(context)) {
                 Navigator.pop(context); // Go back to FlashcardsPage
              }
              
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('All flashcards deleted.'),
                  backgroundColor: Colors.red));
            },
            child: const Text("Delete All"),
          ),
        ],
      ),
    );
  }

  Map<String, List<Flashcard>> _getFilteredAndGroupedCards() {
    List<Flashcard> cardsToDisplay = _editableFlashcards;

    if (_searchTerm.isNotEmpty) {
      cardsToDisplay = _editableFlashcards.where((card) {
        return card.question.toLowerCase().contains(_searchTerm) ||
            card.answer.toLowerCase().contains(_searchTerm) ||
            card.category.toLowerCase().contains(_searchTerm) ||
            (card.pdfName != null && card.pdfName!.toLowerCase().contains(_searchTerm));
      }).toList();
    }

    Map<String, List<Flashcard>> groupedByActualKey = {}; // Group by category or PDF name
    for (var card in cardsToDisplay) {
      // If PDF name exists and is not empty, use it as the primary group key
      // Otherwise, use the category.
      String groupKey = (card.pdfName != null && card.pdfName!.isNotEmpty) ? card.pdfName! : card.category;
      groupedByActualKey.putIfAbsent(groupKey, () => []).add(card);
    }
    
    var sortedKeys = groupedByActualKey.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    Map<String, List<Flashcard>> sortedGrouped = {};
    for (var key in sortedKeys) {
      sortedGrouped[key] = groupedByActualKey[key]!;
    }
    return sortedGrouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme here
    final groupedCards = _getFilteredAndGroupedCards();
    final categories = groupedCards.keys.toList();
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Flashcards...'),
          // backgroundColor and foregroundColor removed to use theme
        ),
        body: Center( // Removed Container with black color
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Flashcards (${_editableFlashcards.length})'),
        backgroundColor: theme.brightness == Brightness.dark ? Colors.black : null, // Use theme-aware colors
        foregroundColor: theme.brightness == Brightness.dark ? Colors.white : null, // Use theme-aware colors
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_remove_rounded),
            tooltip: "Reset All Learned Status",
            onPressed: _resetLearnedStatus,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded), 
            tooltip: "Remove All Flashcards",
            onPressed: _removeAllFlashcards,
          ),
        ],
      ),
      body: Container(
        color: theme.brightness == Brightness.dark ? Colors.black : theme.scaffoldBackgroundColor, // Theme-aware background
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white : theme.textTheme.bodyLarge?.color),
                cursorColor: Colors.blue, // Blue cursor to match theme
                decoration: InputDecoration(
                  hintText: 'Search Q, A, Category, or PDF...',
                  hintStyle: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.6) : theme.hintColor),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.blue), // Blue icon per user preference
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 1.5), // Blue border
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 1.5), // Blue border
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2.0), // Thicker blue border when focused
                  ),
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark ? Colors.black.withOpacity(0.7) : theme.colorScheme.surface.withOpacity(0.3), // Theme-aware fill color
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  suffixIcon: _searchTerm.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.blue), // Blue icon
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: categories.isEmpty
                  ? Center(
                      child: Text(
                        _searchTerm.isNotEmpty
                            ? "No flashcards match '$_searchTerm'."
                            : "No flashcards created yet.",
                        style: theme.textTheme.titleMedium, // Use theme text style
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final groupKey = categories[index]; // This can be a category or a PDF name
                        final cardsInGroup = groupedCards[groupKey]!;
                        // Determine if the groupKey is a PDF name by checking the first card
                        // This assumes all cards in a PDF-named group share that PDF name.
                        bool isPdfGroup = cardsInGroup.isNotEmpty && cardsInGroup.first.pdfName == groupKey;
                        String displayTitle = groupKey;
                        String? lectureSubtitle;

                        if (isPdfGroup && cardsInGroup.isNotEmpty) {
                           // If it's a PDF group, the title is the PDF name.
                           // The subtitle can show the lecture (category) if it's consistent for the group.
                           // For simplicity, taking the category of the first card.
                           if (cardsInGroup.first.category.isNotEmpty && cardsInGroup.first.category != groupKey) {
                             lectureSubtitle = 'Lecture: ${cardsInGroup.first.category}';
                           }
                        }


                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        elevation: 2, // Slightly more elevation for better visibility
                        color: theme.brightness == Brightness.dark ? Colors.black : theme.cardColor, // Theme-aware background
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Colors.blue, width: 1.0) // Blue border per user preference
                        ),
                        child: ExpansionTile(
                          key: PageStorageKey<String>(groupKey),
                          collapsedIconColor: Colors.blue, // Blue icon when collapsed
                          iconColor: Colors.blue, // Blue icon when expanded
                          title: Text(
                            displayTitle,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue, // Blue headings per user preference
                                fontSize: 16,
                                decoration: TextDecoration.underline // Underline per user preference
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${cardsInGroup.length} card(s)',
                                style: TextStyle(
                                  color: theme.brightness == Brightness.dark ? Colors.white : theme.textTheme.bodySmall?.color, // Theme-aware text color
                                  fontSize: 12,
                                )
                              ),
                              if (lectureSubtitle != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    lectureSubtitle,
                                    style: TextStyle(
                                      color: Colors.lightBlue[200], // Light blue for PDF references per user preference
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                    )),
                                ),
                            ],
                          ),
                          initiallyExpanded: _expandedCategories[groupKey] ?? false,
                          onExpansionChanged: (expanding) {
                            setState(() {
                              _expandedCategories[groupKey] = expanding;
                            });
                          },
                          childrenPadding: const EdgeInsets.only(bottom: 8),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          children: cardsInGroup
                              .map((flashcardItem) => ListTile( 
                                    dense: true,
                                    title: Text(
                                        flashcardItem.question,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: theme.brightness == Brightness.dark ? Colors.white : theme.textTheme.titleMedium?.color, // Theme-aware text color
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        )
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          flashcardItem.answer,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.brightness == Brightness.dark ? Colors.white70 : theme.textTheme.bodySmall?.color?.withOpacity(0.9), // Theme-aware text color
                                            fontSize: 12,
                                          )
                                        ),
                                        if (flashcardItem.pdfName != null && flashcardItem.pdfName!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2.0),
                                            child: Text(
                                              '${flashcardItem.pdfName}',
                                              style: TextStyle(
                                                color: Colors.lightBlue[200], // Light blue for PDF references per user preference
                                                fontSize: 10,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                              Icons.edit_note_rounded, 
                                              color: Colors.blue), // Blue per user preference
                                          onPressed: () => _editCard(flashcardItem),
                                          tooltip: "Edit Card",
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_forever_rounded, 
                                              color: Colors.redAccent), // Red for delete action
                                          onPressed: () => _deleteCard(flashcardItem.id),
                                          tooltip: "Delete Card",
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                    leading: Icon(
                                      flashcardItem.isLearned
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      color: flashcardItem.isLearned
                                          ? Colors.green // Green for learned status
                                          : Colors.blue, // Blue for not learned per user preference
                                      size: 20,
                                    ),
                                  ))
                              .toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
        )
      )
      );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}