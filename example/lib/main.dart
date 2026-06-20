import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nepali_transliteration/nepali_transliteration.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nepali Transliteration Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Forest green seed
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF81C784),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const DemoHomeScreen(),
    );
  }
}

class DemoHomeScreen extends StatefulWidget {
  const DemoHomeScreen({super.key});

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _loadError = '';
  int _dictionarySize = 0;

  // Tab 1: Interactive & Sentence Transliteration
  final TextEditingController _interactiveInputController =
      TextEditingController();
  final TextEditingController _bulkInputController = TextEditingController();
  List<String> _candidates = [];
  String _activeWord = '';
  int _activeWordStart = 0;
  int _activeWordEnd = 0;
  String _bulkResult = '';

  // Tab 2: Custom On-Screen Keyboard
  final TextEditingController _keyboardInputController =
      TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _isKeyboardFocused = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _interactiveInputController.addListener(_onInteractiveTextChanged);
    _bulkInputController.addListener(_onBulkTextChanged);
    _keyboardFocusNode.addListener(() {
      setState(() {
        _isKeyboardFocused = _keyboardFocusNode.hasFocus;
      });
    });
    _loadDictionary();
  }

  Future<void> _loadDictionary() async {
    try {
      final dict = await NepaliDictionary.load();
      setState(() {
        _isLoading = false;
        _dictionarySize = dict.size;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _interactiveInputController.dispose();
    _bulkInputController.dispose();
    _keyboardInputController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  // Parses interactive text to extract the current word being typed at the cursor
  void _onInteractiveTextChanged() {
    final text = _interactiveInputController.text;
    final selection = _interactiveInputController.selection;

    if (!selection.isValid || !selection.isCollapsed) {
      setState(() {
        _activeWord = '';
        _candidates = [];
      });
      return;
    }

    final int cursorPosition = selection.baseOffset;
    if (cursorPosition <= 0) {
      setState(() {
        _activeWord = '';
        _candidates = [];
      });
      return;
    }

    // Find the starting boundary of the current word
    int start = cursorPosition - 1;
    while (start >= 0 && !RegExp(r'\s').hasMatch(text[start])) {
      start--;
    }
    start++; // Move to character after the space/newline

    // Find the ending boundary of the current word
    int end = cursorPosition;
    while (end < text.length && !RegExp(r'\s').hasMatch(text[end])) {
      end++;
    }

    final word = text.substring(start, end);
    if (word.trim().isEmpty ||
        RegExp(r'^[0-9\s.,\/#!$%\^&\*;:{}=\-_`~()]+$').hasMatch(word)) {
      setState(() {
        _activeWord = '';
        _candidates = [];
      });
    } else {
      setState(() {
        _activeWord = word;
        _activeWordStart = start;
        _activeWordEnd = end;
        if (NepaliDictionary.isLoaded) {
          _candidates = NepaliDictionary.instance.candidates(word);
        } else {
          _candidates = [convertToNepali(word)];
        }
      });
    }
  }

  // Handles inserting selected candidate into text controller
  void _selectCandidate(String candidate) {
    if (_activeWord.isEmpty) return;

    final text = _interactiveInputController.text;

    // We add a space after the candidate for faster typing flow
    final newWordText = '$candidate ';
    final newText = text.replaceRange(
      _activeWordStart,
      _activeWordEnd,
      newWordText,
    );
    final newCursorOffset = _activeWordStart + newWordText.length;

    // Temporarily remove listener to prevent infinite trigger loop
    _interactiveInputController.removeListener(_onInteractiveTextChanged);
    _interactiveInputController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
    _interactiveInputController.addListener(_onInteractiveTextChanged);

    setState(() {
      _activeWord = '';
      _candidates = [];
    });
  }

  void _onBulkTextChanged() {
    final text = _bulkInputController.text;
    if (text.isEmpty) {
      setState(() {
        _bulkResult = '';
      });
      return;
    }
    setState(() {
      if (NepaliDictionary.isLoaded) {
        _bulkResult = NepaliDictionary.instance.sentence(text);
      } else {
        _bulkResult = convertToNepali(text);
      }
    });
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nepali Transliteration',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.translate), text: 'Transliterate'),
            Tab(icon: Icon(Icons.keyboard), text: 'On-Screen Keyboard'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading Dictionary Asset...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : _loadError.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: cs.error, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load dictionary asset',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadError,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildTransliterateTab(), _buildKeyboardTab()],
            ),
    );
  }

  Widget _buildTransliterateTab() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Info Card
          Card(
            elevation: 0,
            color: cs.primaryContainer.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.primaryContainer),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: cs.primary, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dictionary Loaded Successfully',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Loaded $_dictionarySize keys. You can type in romanized English and it will auto-suggest matching Devanagari words.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onPrimaryContainer.withValues(alpha:0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 1: Realtime Interactive Transliteration
          Text(
            '1. Interactive Suggestion Bar Typing',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Type below (e.g., "namaste nepal", "kaathmaandu"). Tap on suggestions to replace romanized words with correct Nepali.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Suggestion Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _candidates.isNotEmpty ? 48 : 0,
            child: _candidates.isNotEmpty
                ? ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _candidates.length,
                    itemBuilder: (context, index) {
                      final candidate = _candidates[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                        child: ActionChip(
                          label: Text(
                            candidate,
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: cs.primary,
                          elevation: 1,
                          side: BorderSide.none,
                          onPressed: () => _selectCandidate(candidate),
                        ),
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),

          TextField(
            controller: _interactiveInputController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Type romanized Nepali here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
              filled: true,
              fillColor: cs.surfaceContainerLowest,
              suffixIcon: _interactiveInputController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _interactiveInputController.clear();
                        setState(() {
                          _candidates = [];
                          _activeWord = '';
                        });
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _copyToClipboard(
                  context,
                  _interactiveInputController.text,
                  'Copied text to clipboard',
                ),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy Text'),
              ),
            ],
          ),

          const Divider(height: 32),

          // Section 2: Sentence/Bulk Transliteration
          Text(
            '2. Sentence-Level Auto-Transliteration',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This uses the greedy phrase matching algorithm to translate the entire text at once.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _bulkInputController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Enter a full sentence (e.g., "mero desh nepal ho")',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: cs.surfaceContainerLowest,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: cs.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transliteration Result',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () => _copyToClipboard(
                          context,
                          _bulkResult,
                          'Copied result to clipboard',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _bulkResult.isEmpty
                        ? 'Devanagari output will show here...'
                        : _bulkResult,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: _bulkResult.isEmpty
                          ? cs.onSurfaceVariant.withValues(alpha:0.5)
                          : cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardTab() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  color: cs.secondaryContainer.withValues(alpha:0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.keyboard_alt_outlined,
                          color: cs.secondary,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Click on the text field below to display the built-in, custom Devanagari on-screen keyboard. Text shaping is done automatically.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Input Area',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _keyboardInputController,
                  focusNode: _keyboardFocusNode,
                  readOnly: true, // Prevents system keyboard
                  showCursor: true, // Retains blinking cursor
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Tap here to type using the Devanagari keyboard...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerLowest,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        _keyboardInputController.clear();
                      },
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear All'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _copyToClipboard(
                        context,
                        _keyboardInputController.text,
                        'Copied Devanagari text to clipboard',
                      ),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Devanagari'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Show/hide on-screen keyboard
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: _isKeyboardFocused
              ? NepaliKeyboard(
                  controller: _keyboardInputController,
                  onDone: () {
                    _keyboardFocusNode.unfocus();
                  },
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
