import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/models/questions.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:intl/intl.dart';
import 'package:serenity_mobile/screens/doctor_dashboard.dart';

/// Simple class to group subcategory name with its questions.
class Subcategory {
  final String name; // e.g. "Anxiety - Anxious Mood"
  // Map of questionKey -> Questions object
  final Map<String, Questions> questions;

  Subcategory({required this.name, required this.questions});
}

class UserQuestionnaire extends StatefulWidget {
  const UserQuestionnaire({Key? key}) : super(key: key);

  @override
  _UserQuestionnaireState createState() => _UserQuestionnaireState();
}

class _UserQuestionnaireState extends State<UserQuestionnaire> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// The user's conditions (e.g., ["Anxiety", "Insomnia"])
  List<String> _userConditions = [];

  /// Merged subcategories from all conditions, keyed by "Condition - Subcategory"
  Map<String, Subcategory> _subcategories = {};
  List<String> _subcategoryNames = []; // sorted list of subcategory keys

  int _currentSubcategoryIndex = 0;
  int _currentQuestionIndex = 0;

  /// For storing user answers in memory:
  ///   _selectedAnswers["Condition - SubcategoryName"][questionKey] = chosenLegend
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

  /// Step 1: Fetch all user conditions into _userConditions.
  /// Step 2: Combine subcategories/questions from each condition.
  Future<void> _fetchUserConditionsAndCombineQuestions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("No user logged in.");
      return;
    }

    final userUID = user.uid;
    final userRef = _dbRef.child('administrator/users/$userUID/conditions');
    final userEvent = await userRef.once();

    if (!userEvent.snapshot.exists) {
      debugPrint("No conditions found in DB.");
      return;
    }

    final conditionData = userEvent.snapshot.value;
    if (conditionData is List && conditionData.isNotEmpty) {
      // e.g. ["Anxiety", "Insomnia"]
      _userConditions = conditionData.map((c) => c.toString().trim()).toList();
    } else if (conditionData is Map && conditionData.isNotEmpty) {
      // e.g. {0: "Anxiety", 1: "Insomnia"}
      _userConditions = conditionData.values
          .map((c) => c.toString().trim())
          .toList()
          .cast<String>();
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

  /// Step 2 (continued): For each condition, load from:
  ///   /administrator/defaultQuestionnaires/{condition}/{condition}
  /// Then store in _subcategories using "Condition - SubcatName" as the key.
  Future<void> _combineAllConditionQuestions() async {
    // Clear old data
    _subcategories.clear();
    _subcategoryNames.clear();
    _selectedAnswers.clear();
    _subcategoryTotals.clear();
    _overallTotal = 0.0;

    // For each condition in the user's list
    for (String condition in _userConditions) {
      final baseRef = _dbRef
          .child('administrator/defaultQuestionnaires/$condition/$condition');
      final baseEvent = await baseRef.once();

      if (baseEvent.snapshot.exists && baseEvent.snapshot.value is Map) {
        final categoriesMap = Map<dynamic, dynamic>.from(
          baseEvent.snapshot.value as Map<dynamic, dynamic>,
        );

        // For each subcategory
        for (var rawSubcatKey in categoriesMap.keys) {
          final subcatData = categoriesMap[rawSubcatKey];
          if (subcatData is Map) {
            // We'll create a merged key, e.g. "Anxiety - Anxious Mood"
            final trimmedSubcatKey = rawSubcatKey.toString().trim();
            final mergedKey = "$condition - $trimmedSubcatKey";

            final subcatMap = Map<dynamic, dynamic>.from(subcatData);
            Map<String, Questions> questionsMap = {};

            // For each question in this subcategory
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
                      choices.add({
                        'text': choiceText,
                        'value': score,
                      });
                    }
                    questionsMap[rawQuestionKey.toString()] = Questions(
                      question: questionText,
                      choices: choices,
                    );
                  }
                }
              }
            }

            // Store the subcategory
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

  /// Helper: the current merged subcategory key
  String get _currentSubcategoryKey {
    if (_subcategoryNames.isNotEmpty &&
        _currentSubcategoryIndex < _subcategoryNames.length) {
      return _subcategoryNames[_currentSubcategoryIndex];
    }
    return "";
  }

  /// Helper: current subcategory object
  Subcategory? get _currentSubcategory {
    if (_subcategories.containsKey(_currentSubcategoryKey)) {
      return _subcategories[_currentSubcategoryKey];
    }
    return null;
  }

  /// Helper: question keys for the current subcategory
  List<String> get _currentQuestionKeys {
    final subcat = _currentSubcategory;
    if (subcat != null) {
      return subcat.questions.keys.toList();
    }
    return [];
  }

  /// Helper: current question object
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

  /// Helper: current question key (like "Q1")
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

  /// Save a single answer to:
  /// /administrator/users/{userUID}/all_answers/{condition}/{condition}/{subcategoryName}/{questionKey}
  /// We parse the condition and subcategory from the merged key, e.g. "Anxiety - Anxious Mood".
  void _saveAnswer({
    required String mergedSubcatKey,
    required String questionKey,
    required String questionText,
    required String legend,
    required double value,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userUID = user.uid;

    // Extract condition and subcategory
    final parts = mergedSubcatKey.split(" - ");
    final condition = parts[0].trim();
    final subcatName =
        (parts.length > 1) ? parts[1].trim() : mergedSubcatKey.trim();

    final answersRef = _dbRef.child(
      'administrator/users/$userUID/all_answers/$condition/$condition/$subcatName/$questionKey',
    );

    await answersRef.set({
      'question': questionText,
      'legend': legend,
      'value': value,
    });
  }

  /// Called when user selects a radio button. We:
  /// - Update in-memory totals
  /// - Save to Firebase
  /// - Move on
  void _onAnswerSelected(String? legend) {
    if (legend == null) return;

    final question = _currentQuestion;
    final questionKey = _currentQuestionKey;
    final mergedKey = _currentSubcategoryKey;
    if (question == null || questionKey == null || mergedKey.isEmpty) return;

    // Find the numeric value for the chosen legend
    double chosenValue = 0.0;
    for (var choice in question.choices) {
      if (choice['text'] == legend) {
        chosenValue = choice['value'];
        break;
      }
    }

    // Store in memory
    _selectedAnswers[mergedKey]![questionKey] = legend;

    // Update subcategory total
    _subcategoryTotals[mergedKey] =
        (_subcategoryTotals[mergedKey] ?? 0.0) + chosenValue;

    // Update overall total
    _overallTotal += chosenValue;

    // Save to Firebase
    _saveAnswer(
      mergedSubcatKey: mergedKey,
      questionKey: questionKey,
      questionText: question.question,
      legend: legend,
      value: chosenValue,
    );

    _goToNext();
  }

  /// Moves to the next question or next subcategory, or finishes if all done.
  void _goToNext() {
    setState(() {
      // More questions in current subcategory?
      if (_currentQuestionIndex < _currentQuestionKeys.length - 1) {
        _currentQuestionIndex++;
      } else {
        // Next subcategory
        if (_currentSubcategoryIndex < _subcategoryNames.length - 1) {
          _currentSubcategoryIndex++;
          _currentQuestionIndex = 0;
        } else {
          // Done with all
          _saveFinalData();
          _endQuestion();
        }
      }
    });
  }

  /// Moves to previous question if possible
  void _goToPrevious() {
    setState(() {
      if (_currentQuestionIndex > 0) {
        _currentQuestionIndex--;
      } else {
        // If we’re at first question of subcategory, go to previous subcategory
        if (_currentSubcategoryIndex > 0) {
          _currentSubcategoryIndex--;
          _currentQuestionIndex =
              _subcategories[_currentSubcategoryKey]!.questions.length - 1;
        }
      }
    });
  }

  /// Saves subcategory totals, plus total_value, for each condition.
  /// Also marks questionnaire_completed = true.
  Future<void> _saveFinalData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userUID = user.uid;

    // 1) Build a structure of subcat totals per condition
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

      // Store subcategory total
      subcatTotalsByCondition[condition]![subcatName] = subTotal;

      // Add to condition total
      conditionTotals[condition] = conditionTotals[condition]! + subTotal;
    }

    // 2) Write each condition’s subcategories, total_value, timestamp
    for (String condition in subcatTotalsByCondition.keys) {
      final subMap = subcatTotalsByCondition[condition]!;
      final condRef = _dbRef.child(
        'administrator/users/$userUID/all_answers/$condition/$condition',
      );

      // Write each subcategory total
      for (String subcatName in subMap.keys) {
        final subTotal = subMap[subcatName] ?? 0.0;
        await condRef.child('$subcatName/subcategory_total').set(subTotal);
      }

      // Write overall total and timestamp
      await condRef.update({
        'total_value': conditionTotals[condition],
        'timestamp': _getFormattedTimestamp(),
      });
    }

    // 3) Mark the user’s questionnaire as completed
    final userRef = _dbRef.child('administrator/users/$userUID');
    await userRef.update({'questionnaire_completed': true});

    debugPrint("All data saved. questionnaire_completed = true");
  }

  /// Shows a completion dialog, then navigates to DoctorDashboard.
  void _endQuestion() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Well done!"),
          content: const Text(
            "Thank you for answering the questionnaire(s). "
            "This helps greatly in diagnosing your condition(s). "
            "Have a great day!",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => DoctorDashboard()),
                );
                // Optionally reset local state
                setState(() {
                  _currentSubcategoryIndex = 0;
                  _currentQuestionIndex = 0;
                  _overallTotal = 0.0;
                  _subcategories.clear();
                  _subcategoryNames.clear();
                  _subcategoryTotals.clear();
                  _selectedAnswers.clear();
                  _userConditions.clear();
                });
              },
              child: const Text("Exit"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // If no conditions or no subcategories, show a loading spinner
    if (_userConditions.isEmpty || _subcategoryNames.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final question = _currentQuestion;
    final questionKey = _currentQuestionKey;

    // Calculate total number of questions across all subcategories
    final totalQuestions = _subcategories.values.fold(
      0,
      (sum, subcat) => sum + subcat.questions.length,
    );

    // How many questions we've already answered (or are on)
    int questionsSoFar = 0;
    for (int i = 0; i < _currentSubcategoryIndex; i++) {
      questionsSoFar += _subcategories[_subcategoryNames[i]]!.questions.length;
    }
    questionsSoFar += (_currentQuestionIndex + 1);

    // For the progress bar
    final progressBarValue =
        (totalQuestions == 0) ? 0.0 : (questionsSoFar / totalQuestions);

    // Diamond icons for each question
    List<Widget> diamondIcons = List.generate(totalQuestions, (index) {
      return Image.asset(
        'assets/diamond.png', // ensure you have diamond.png in your assets
        height: 15,
        width: 15,
        color: index < questionsSoFar ? Colors.blue : Colors.grey,
      );
    });

    // The user’s current selection, if any
    final mergedKey = _currentSubcategoryKey;
    final selectedValue = (mergedKey.isNotEmpty && questionKey != null)
        ? _selectedAnswers[mergedKey]![questionKey]
        : null;

    return Scaffold(
      backgroundColor: AppColors.lighterGreen,
      body: SingleChildScrollView(
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
                      onPressed: (questionsSoFar > 1) ? _goToPrevious : null,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.lightGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40, right: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "Initial Questionnaire",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Show current merged subcategory key
                          if (mergedKey.isNotEmpty)
                            Text(
                              mergedKey,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 2),

            // Progress bar + diamond icons
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

            // Current question text
            if (question != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  question.question,
                  textAlign: TextAlign.left,
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
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                      onChanged: (value) {
                        setState(() {
                          _selectedAnswers[mergedKey]![questionKey!] = value;
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
    );
  }
}
