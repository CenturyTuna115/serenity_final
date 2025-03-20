import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/models/questions.dart'; // Adjust if needed
import 'package:serenity_mobile/resources/colors.dart'; // Adjust if needed
import 'package:intl/intl.dart';
import 'homepage.dart'; // Your home page

///  to hold subcategory name and questions.
class Subcategory {
  final String name; // e.g. "Insomnia - Think about a typical night"
  final Map<String, Questions> questions; // questionKey -> Questions object

  Subcategory({required this.name, required this.questions});
}

class Questionnaires extends StatefulWidget {
  const Questionnaires({Key? key}) : super(key: key);

  @override
  _QuestionnairesState createState() => _QuestionnairesState();
}

class _QuestionnairesState extends State<Questionnaires> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// The user’s conditions, fetched from `/administrator/users/{userUID}/conditions`
  List<String> _userConditions = [];

  /// Merged subcategories from *all* conditions, keyed by "Condition - Subcategory"
  Map<String, Subcategory> _subcategories = {};
  List<String> _subcategoryNames = []; // sorted list of merged subcategory keys

  /// Indices to track the user’s position in the single, merged flow
  int _currentSubcategoryIndex = 0;
  int _currentQuestionIndex = 0;

  /// For storing user answers in memory:
  /// _selectedAnswers["Condition - SubcategoryName"][questionKey] = legend
  Map<String, Map<String, String?>> _selectedAnswers = {};

  /// For each merged subcategory key, track a numeric total
  Map<String, double> _subcategoryTotals = {};

  /// The sum of *all* subcategories from *all* conditions
  double _overallTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchUserConditionsAndCombineQuestions();
  }

  /// Utility: returns a timestamp in UTC+8
  String _getFormattedTimestamp() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
  }

  /// Step 1: Fetch user conditions. Then Step 2: Load + merge questions.
  Future<void> _fetchUserConditionsAndCombineQuestions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("No user logged in.");
      return;
    }
    final userUID = user.uid;

    // Fetch user conditions
    final userRef = _dbRef.child('administrator/users/$userUID/conditions');
    final userEvent = await userRef.once();

    if (!userEvent.snapshot.exists) {
      debugPrint("No conditions found in DB.");
      return;
    }

    var conditionData = userEvent.snapshot.value;
    if (conditionData is List && conditionData.isNotEmpty) {
      _userConditions = List<String>.from(conditionData);
    } else if (conditionData is Map && conditionData.isNotEmpty) {
      _userConditions = List<String>.from(conditionData.values);
    }

    debugPrint("User conditions: $_userConditions");
    if (_userConditions.isEmpty) {
      debugPrint("No conditions in the user's list.");
      return;
    }

    // Now combine subcategories from ALL conditions into one big set
    await _combineAllConditionQuestions();

    // Rebuild UI with merged subcategories
    setState(() {
      _currentSubcategoryIndex = 0;
      _currentQuestionIndex = 0;
    });
  }

  /// Step 2 (continued): Load subcategories/questions for each condition
  /// and merge them into _subcategories using "Condition - SubcatName" as a key.
  Future<void> _combineAllConditionQuestions() async {
    // Clear old data
    _subcategories.clear();
    _subcategoryNames.clear();
    _selectedAnswers.clear();
    _subcategoryTotals.clear();
    _overallTotal = 0.0;

    // For each condition, fetch from /administrator/defaultQuestionnaires/{condition}/{condition}
    for (String condition in _userConditions) {
      final baseRef = _dbRef
          .child('administrator/defaultQuestionnaires/$condition/$condition');
      final baseEvent = await baseRef.once();

      if (baseEvent.snapshot.exists && baseEvent.snapshot.value is Map) {
        final categoriesMap = Map<dynamic, dynamic>.from(
          baseEvent.snapshot.value as Map<dynamic, dynamic>,
        );

        // For each subcategory in this condition
        for (var rawSubcatKey in categoriesMap.keys) {
          final subcatData = categoriesMap[rawSubcatKey];
          if (subcatData is Map) {
            // We'll create a merged key, e.g. "Insomnia - Think about a typical night"
            // Also trim the subcategory key in case there's trailing space
            final trimmedSubcatKey = rawSubcatKey.toString().trim();
            final mergedKey = "$condition - $trimmedSubcatKey";
            final subcatMap = Map<dynamic, dynamic>.from(subcatData);

            Map<String, Questions> questionsMap = {};

            // Each subcategory can have multiple questions
            for (var rawQuestionKey in subcatMap.keys) {
              final questionData = subcatMap[rawQuestionKey];
              if (questionData is Map<dynamic, dynamic>) {
                if (questionData.containsKey('question') &&
                    questionData.containsKey('legend') &&
                    questionData.containsKey('value')) {
                  final questionText = questionData['question'] as String;
                  final legends = List<dynamic>.from(questionData['legend']);
                  final values = List<dynamic>.from(questionData['value']);

                  if (legends.length == values.length) {
                    List<Map<String, dynamic>> choices = [];
                    for (int i = 0; i < legends.length; i++) {
                      final choiceText = legends[i].toString();
                      final score =
                          double.tryParse(values[i].toString()) ?? 0.0;
                      choices.add({'text': choiceText, 'value': score});
                    }

                    questionsMap[rawQuestionKey.toString()] = Questions(
                      question: questionText,
                      choices: choices,
                    );
                  }
                }
              }
            }

            // Store in _subcategories
            _subcategories[mergedKey] = Subcategory(
              name: mergedKey,
              questions: questionsMap,
            );
          }
        }
      }
    }

    // Build the list of subcategory keys (the merged keys)
    _subcategoryNames = _subcategories.keys.toList();

    // Initialize local tracking
    for (var mergedKey in _subcategoryNames) {
      _subcategoryTotals[mergedKey] = 0.0;
      _selectedAnswers[mergedKey] = {};
    }
  }

  /// Helper: Current merged subcategory key
  String get _currentSubcategoryKey {
    if (_subcategoryNames.isNotEmpty &&
        _currentSubcategoryIndex < _subcategoryNames.length) {
      return _subcategoryNames[_currentSubcategoryIndex];
    }
    return "";
  }

  /// Helper: Current subcategory object
  Subcategory? get _currentSubcategory {
    if (_subcategories.containsKey(_currentSubcategoryKey)) {
      return _subcategories[_currentSubcategoryKey];
    }
    return null;
  }

  /// Helper: The list of question keys for the current subcategory
  List<String> get _currentQuestionKeys {
    final subcat = _currentSubcategory;
    if (subcat != null) {
      return subcat.questions.keys.toList();
    }
    return [];
  }

  /// Helper: The current question object
  Questions? get _currentQuestion {
    final subcat = _currentSubcategory;
    if (subcat != null) {
      final keys = subcat.questions.keys.toList();
      if (_currentQuestionIndex < keys.length) {
        return subcat.questions[keys[_currentQuestionIndex]];
      }
    }
    return null;
  }

  /// Helper: The key (like "Q1") of the current question
  String? get _currentQuestionKey {
    final subcat = _currentSubcategory;
    if (subcat != null) {
      final keys = subcat.questions.keys.toList();
      if (_currentQuestionIndex < keys.length) {
        return keys[_currentQuestionIndex];
      }
    }
    return null;
  }

  /// Save a single answer to Firebase. We need to parse out the condition and subcategory
  /// from the merged subcategory key, e.g. "Insomnia - Think about a typical night".
  void _saveAnswer(
    String mergedSubcatKey,
    String questionKey,
    String questionText,
    String legend,
    double value,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userUID = user.uid;

    // 1) Split the merged key into condition and subcategory
    final parts = mergedSubcatKey.split(" - ");
    final condition = parts[0].trim();
    final subcategoryName =
        (parts.length > 1) ? parts[1].trim() : mergedSubcatKey.trim();

    // 2) Save under 3-level path: /$condition/$condition/$subcategoryName/$questionKey
    final answersRef = _dbRef.child(
      'administrator/users/$userUID/all_answers/$condition/$condition/$subcategoryName/$questionKey',
    );

    await answersRef.set({
      'question': questionText,
      'legend': legend,
      'value': value,
    });
  }

  /// Called when the user selects a radio button.
  void _onAnswerSelected(String? legend) {
    if (legend == null) return;

    final question = _currentQuestion;
    final questionKey = _currentQuestionKey;
    final mergedSubcatKey = _currentSubcategoryKey;
    if (question == null || questionKey == null || mergedSubcatKey.isEmpty) {
      return;
    }

    // Find the numeric value for this chosen legend
    double chosenValue = 0.0;
    for (var choice in question.choices) {
      if (choice['text'] == legend) {
        chosenValue = choice['value'];
        break;
      }
    }

    // Store in memory
    _selectedAnswers[mergedSubcatKey]![questionKey] = legend;

    // Update subcategory total
    _subcategoryTotals[mergedSubcatKey] =
        (_subcategoryTotals[mergedSubcatKey] ?? 0.0) + chosenValue;

    // Update the overall total
    _overallTotal += chosenValue;

    // Save to Firebase
    _saveAnswer(
      mergedSubcatKey,
      questionKey,
      question.question,
      legend,
      chosenValue,
    );

    // Go to next question
    _goToNext();
  }

  /// Moves forward to the next question. If we finish a subcategory, move to the next subcategory.
  /// If we finish *all* subcategories, end the questionnaire.
  void _goToNext() {
    setState(() {
      // 1) More questions in this subcategory?
      if (_currentQuestionIndex < _currentQuestionKeys.length - 1) {
        _currentQuestionIndex++;
      } else {
        // 2) Subcategory done: move to the next subcategory
        if (_currentSubcategoryIndex < _subcategoryNames.length - 1) {
          _currentSubcategoryIndex++;
          _currentQuestionIndex = 0;
        } else {
          // 3) All subcategories are done
          _endQuestion();
        }
      }
    });
  }

  /// Optional: let user go back a question
  void _goToPrevious() {
    setState(() {
      if (_currentQuestionIndex > 0) {
        _currentQuestionIndex--;
      } else {
        if (_currentSubcategoryIndex > 0) {
          _currentSubcategoryIndex--;
          _currentQuestionIndex =
              _subcategories[_currentSubcategoryKey]!.questions.length - 1;
        }
      }
    });
  }

  /// Called once at the very end of the entire questionnaire.
  void _endQuestion() {
    // 1) Save all subcategory totals and overall totals per condition
    _saveAllData();

    // 2) Show a completion dialog
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Well done!"),
          content: const Text("Thank you for answering all questions."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => HomePage()),
                );

                // Reset if needed
                setState(() {
                  _userConditions.clear();
                  _subcategories.clear();
                  _subcategoryNames.clear();
                  _selectedAnswers.clear();
                  _subcategoryTotals.clear();
                  _overallTotal = 0.0;
                  _currentSubcategoryIndex = 0;
                  _currentQuestionIndex = 0;
                });
              },
              child: const Text("Exit"),
            ),
          ],
        );
      },
    );
  }

  /// Splits out each subcategory key into condition and subcategory,
  /// sums them up, and writes them to Firebase. Also updates `last_answered`.
  Future<void> _saveAllData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userUID = user.uid;

    // 1) Build a structure of subcategory totals per condition
    Map<String, Map<String, double>> subcatTotalsByCondition = {};
    Map<String, double> conditionTotals = {};

    for (String mergedKey in _subcategoryTotals.keys) {
      final parts = mergedKey.split(" - ");
      final condition = parts[0].trim();
      final subcatName =
          (parts.length > 1) ? parts[1].trim() : mergedKey.trim();

      final subTotal = _subcategoryTotals[mergedKey] ?? 0.0;

      // Initialize
      subcatTotalsByCondition.putIfAbsent(condition, () => {});
      conditionTotals.putIfAbsent(condition, () => 0.0);

      // Store the subcategory total
      subcatTotalsByCondition[condition]![subcatName] = subTotal;

      // Add to the condition total
      conditionTotals[condition] = conditionTotals[condition]! + subTotal;
    }

    // 2) Write each condition’s subcategories, total_value, and timestamp
    for (String condition in subcatTotalsByCondition.keys) {
      final subMap = subcatTotalsByCondition[condition]!;
      // Use the 3-level path here:
      final condRef = _dbRef.child(
        'administrator/users/$userUID/all_answers/$condition/$condition',
      );

      // Write each subcategory’s total
      for (String subcatName in subMap.keys) {
        final subTotal = subMap[subcatName] ?? 0.0;
        await condRef.child('$subcatName/subcategory_total').set(subTotal);
      }

      // Write the overall total and timestamp
      await condRef.update({
        'total_value': conditionTotals[condition],
        'timestamp': _getFormattedTimestamp(),
      });
    }

    debugPrint("Saved all subcategory totals + condition totals.");

    // 3) Update last_answered to store all conditions
    DatabaseReference lastAnsweredRef =
        _dbRef.child('administrator/users/$userUID/last_answered');
    final event = await lastAnsweredRef.once();

    List<String> previouslyAnswered = [];
    if (event.snapshot.exists) {
      var data = event.snapshot.value;
      if (data is Map && data['conditions'] is List) {
        previouslyAnswered = List<String>.from(data['conditions']);
      }
    }

    // Add all user conditions
    for (String c in _userConditions) {
      if (!previouslyAnswered.contains(c)) {
        previouslyAnswered.add(c);
      }
    }

    await lastAnsweredRef.set({
      'conditions': previouslyAnswered,
      'timestamp': _getFormattedTimestamp(),
    });

    debugPrint(
        "Updated last_answered with all conditions: $previouslyAnswered");
  }

  @override
  Widget build(BuildContext context) {
    // If no conditions, show a loading spinner
    if (_userConditions.isEmpty || _subcategoryNames.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final question = _currentQuestion;
    final questionKey = _currentQuestionKey;

    // Calculate overall progress across *all* subcategories
    final totalQuestions = _subcategories.values.fold(
      0,
      (sum, subcat) => sum + subcat.questions.length,
    );

    // How many questions we’ve already gone through in the merged list
    int questionIndexSoFar = 0;
    for (int i = 0; i < _currentSubcategoryIndex; i++) {
      questionIndexSoFar +=
          _subcategories[_subcategoryNames[i]]!.questions.length;
    }
    // Add current question index
    questionIndexSoFar += (_currentQuestionIndex + 1);

    final progressBarValue =
        (totalQuestions == 0) ? 0.0 : (questionIndexSoFar / totalQuestions);

    // Build the diamond icons (1 icon per question)
    List<Widget> diamondIcons = List.generate(totalQuestions, (index) {
      return Image.asset(
        'assets/diamond.png', // Ensure you have diamond.png in assets
        height: 15,
        width: 15,
        color: index < questionIndexSoFar ? Colors.blue : Colors.grey,
      );
    });

    // The user’s current selection, if any
    final mergedKey = _currentSubcategoryKey;
    final selectedValue = (mergedKey.isNotEmpty && questionKey != null)
        ? _selectedAnswers[mergedKey]![questionKey]
        : null;

    return Scaffold(
      backgroundColor: AppColors.lighterGreen,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              children: [
                // Header
                Container(
                  height: 120,
                  color: AppColors.lightGreen,
                  child: Row(
                    children: [
                      // Back button if not on the very first question
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: ElevatedButton(
                          onPressed:
                              (questionIndexSoFar > 1) ? _goToPrevious : null,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: AppColors.lightGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          child:
                              const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40, right: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                "Weekly Questions",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // Show the merged subcategory key
                              if (mergedKey.isNotEmpty)
                                Text(
                                  mergedKey,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 2),
                // Stack to hold the progress bar + diamond icons
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 15,
                      width: double.infinity,
                      child: LinearProgressIndicator(
                        value: progressBarValue,
                        backgroundColor: AppColors.dirtyWhite,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.progressBarColor,
                        ),
                        minHeight: 15,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: diamondIcons,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Question text
                if (question != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      question.question,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Radio choices
                if (question != null)
                  ...question.choices.map((choice) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        child: RadioListTile<String>(
                          tileColor: AppColors.dirtyWhite,
                          title: Text(choice['text']),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 30,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          value: choice['text'],
                          groupValue: selectedValue,
                          onChanged: (String? value) {
                            setState(() {
                              _selectedAnswers[mergedKey]![questionKey!] =
                                  value;
                            });
                            // Slight delay for UI
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              () => _onAnswerSelected(value),
                            );
                          },
                        ),
                      ),
                    );
                  }).toList(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
