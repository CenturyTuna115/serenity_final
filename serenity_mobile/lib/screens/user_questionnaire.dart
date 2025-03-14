import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/models/questions.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:intl/intl.dart';
import 'package:serenity_mobile/screens/doctor_dashboard.dart';

/// Simple class to group subcategory name with its questions.
class Subcategory {
  final String name; // e.g. "Anxious Mood"
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

  // Subcategories loaded from Firebase
  Map<String, Subcategory> _subcategories = {};
  List<String> _subcategoryNames = [];
  int _currentSubcategoryIndex = 0;

  // Current question index within the selected subcategory
  int _currentQuestionIndex = 0;

  // Keep track of user’s selected answers:
  // _selectedAnswers[subcategoryName][questionKey] = chosenLegend
  Map<String, Map<String, String?>> _selectedAnswers = {};

  // Subcategory totals and overall total
  Map<String, double> _subcategoryTotals = {};
  double _overallTotal = 0.0;

  // The user's condition (e.g., "Anxiety")
  String? _userCondition;

  @override
  void initState() {
    super.initState();
    _fetchUserConditionAndSubcategories();
  }

  /// Formats the current time in UTC+8 as 'yyyy-MM-dd HH:mm:ss'
  String _getFormattedTimestamp() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return formatter.format(now.toUtc().add(const Duration(hours: 8)));
  }

  /// Fetches the user's condition, then loads subcategories + questions from defaultQuestionnaires.
  void _fetchUserConditionAndSubcategories() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("No user logged in.");
      return;
    }

    final userUID = user.uid;
    final userRef = _dbRef.child('administrator/users/$userUID/conditions');
    final userEvent = await userRef.once();

    if (userEvent.snapshot.exists) {
      var userConditionData = userEvent.snapshot.value;
      if (userConditionData is List && userConditionData.isNotEmpty) {
        _userCondition = userConditionData[0];
        debugPrint("User condition: $_userCondition");

        _fetchSubcategories();
      } else {
        debugPrint("User condition data is empty or not a list.");
      }
    } else {
      debugPrint("Failed to fetch user condition data.");
    }
  }

  /// Loads subcategories from: /administrator/defaultQuestionnaires/{condition}/{condition}
  /// and stores them in _subcategories as: subcategoryName -> Subcategory object
  void _fetchSubcategories() async {
    if (_userCondition == null) return;

    final baseRef = _dbRef.child(
      'administrator/defaultQuestionnaires/$_userCondition/$_userCondition',
    );

    final baseEvent = await baseRef.once();
    if (baseEvent.snapshot.exists && baseEvent.snapshot.value is Map) {
      // Copy snapshot data to avoid concurrent modification issues
      final rawMap = Map<dynamic, dynamic>.from(
        baseEvent.snapshot.value as Map<dynamic, dynamic>,
      );

      final Map<String, Subcategory> tempSubcategories = {};

      // Each key in rawMap is a subcategory name, e.g. "Anxious Mood", "Autonomic Symptoms"
      for (var rawSubcatKey in rawMap.keys.toList()) {
        final subcatKey = rawSubcatKey.toString();
        final subcatData = rawMap[rawSubcatKey];

        if (subcatData is Map) {
          // Convert to a local Map
          final subcatMap = Map<dynamic, dynamic>.from(subcatData);
          final Map<String, Questions> questionsMap = {};

          // Each key in subcatMap is a questionKey, e.g. "Q1", "Q2"
          for (var rawQuestionKey in subcatMap.keys.toList()) {
            final questionKey = rawQuestionKey.toString();
            final questionData = subcatMap[rawQuestionKey];

            if (questionData is Map<dynamic, dynamic>) {
              if (questionData.containsKey('question') &&
                  questionData.containsKey('legend') &&
                  questionData.containsKey('value')) {
                final questionText = questionData['question'] as String;
                final legends = questionData['legend'] as List<dynamic>;
                final values = questionData['value'] as List<dynamic>;

                // Validate lengths
                if (legends.length == values.length) {
                  final List<Map<String, dynamic>> choices = [];
                  for (int i = 0; i < legends.length; i++) {
                    final choiceText = legends[i].toString();
                    final score = double.tryParse(values[i].toString()) ?? 0.0;
                    choices.add({
                      'text': choiceText,
                      'value': score,
                    });
                  }
                  // Create a Questions object
                  questionsMap[questionKey] = Questions(
                    question: questionText,
                    choices: choices,
                  );
                }
              }
            }
          }

          // Build a Subcategory object
          tempSubcategories[subcatKey] = Subcategory(
            name: subcatKey,
            questions: questionsMap,
          );
        }
      }

      // Update state
      setState(() {
        _subcategories = tempSubcategories;
        _subcategoryNames = _subcategories.keys.toList();

        // Initialize subcategory totals and answer maps
        for (var name in _subcategoryNames) {
          _subcategoryTotals[name] = 0.0;
          _selectedAnswers[name] = {};
        }

        // Start at the first subcategory, first question
        _currentSubcategoryIndex = 0;
        _currentQuestionIndex = 0;
      });
    } else {
      debugPrint(
          "No subcategories found for $_userCondition at ${baseRef.path}");
    }
  }

  /// Helper: get the name of the current subcategory
  String get _currentSubcategoryName => (_subcategoryNames.isNotEmpty &&
          _currentSubcategoryIndex < _subcategoryNames.length)
      ? _subcategoryNames[_currentSubcategoryIndex]
      : '';

  /// Helper: get the list of question keys in the current subcategory
  List<String> get _currentQuestionKeys {
    if (_subcategories.containsKey(_currentSubcategoryName)) {
      return _subcategories[_currentSubcategoryName]!.questions.keys.toList();
    }
    return [];
  }

  /// Helper: get the current Questions object
  Questions? get _currentQuestion {
    if (_subcategories.containsKey(_currentSubcategoryName)) {
      final subcat = _subcategories[_currentSubcategoryName]!;
      final keys = subcat.questions.keys.toList();
      if (_currentQuestionIndex < keys.length) {
        final qKey = keys[_currentQuestionIndex];
        return subcat.questions[qKey];
      }
    }
    return null;
  }

  /// Helper: get the current questionKey
  String? get _currentQuestionKey {
    if (_subcategories.containsKey(_currentSubcategoryName)) {
      final keys =
          _subcategories[_currentSubcategoryName]!.questions.keys.toList();
      if (_currentQuestionIndex < keys.length) {
        return keys[_currentQuestionIndex];
      }
    }
    return null;
  }

  /// Save a single answer to:
  /// /administrator/users/{userUID}/all_answers/{condition}/{condition}/{subcategoryName}/{questionKey}
  void _saveAnswer({
    required String subcategoryName,
    required String questionKey,
    required String questionText,
    required String legend,
    required double value,
  }) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || _userCondition == null) return;

    final userUID = user.uid;
    final condition = _userCondition!;

    final answersRef = _dbRef.child(
      'administrator/users/$userUID/all_answers/$condition/$condition/$subcategoryName/$questionKey',
    );

    await answersRef.set({
      'question': questionText,
      'legend': legend,
      'value': value,
    });
  }

  /// Once all questions are done, store each subcategory’s total, plus total_value and timestamp.
  /// Also mark `questionnaire_completed = true`.
  void _saveFinalData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || _userCondition == null) return;

    final userUID = user.uid;
    final condition = _userCondition!;

    // Write subcategory totals
    final conditionRef = _dbRef.child(
      'administrator/users/$userUID/all_answers/$condition/$condition',
    );

    for (var subcatName in _subcategoryNames) {
      final subTotal = _subcategoryTotals[subcatName] ?? 0.0;
      await conditionRef.child('$subcatName/subcategory_total').set(subTotal);
    }

    // Write overall total and timestamp
    await conditionRef.update({
      'total_value': _overallTotal,
      'timestamp': _getFormattedTimestamp(),
    });

    // Mark the user’s questionnaire as completed
    final userRef = _dbRef.child('administrator/users/$userUID');
    await userRef.update({
      'questionnaire_completed': true,
    });

    debugPrint(
        "Final data saved under all_answers/$condition/$condition. Questionnaire completed.");
  }

  /// Shows a completion dialog, then navigates to the DoctorDashboard.
  void _endQuestion() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Well done!"),
          content: const Text(
            "Thank you for answering the initial questionnaire. "
            "This helps greatly in diagnosing your condition. "
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
                });
              },
              child: const Text("Exit"),
            ),
          ],
        );
      },
    );
  }

  /// Called when user selects a radio button. Stores the answer, updates totals, goes to next question.
  void _onAnswerSelected(String? legend) {
    if (legend == null) return;
    final question = _currentQuestion;
    final questionKey = _currentQuestionKey;
    if (question == null || questionKey == null) return;

    // Find the chosen value
    double chosenValue = 0.0;
    for (var choice in question.choices) {
      if (choice['text'] == legend) {
        chosenValue = choice['value'];
        break;
      }
    }

    // Save in memory
    _selectedAnswers[_currentSubcategoryName]![questionKey] = legend;

    // Update subcategory total
    _subcategoryTotals[_currentSubcategoryName] =
        (_subcategoryTotals[_currentSubcategoryName] ?? 0.0) + chosenValue;

    // Update overall total
    _overallTotal += chosenValue;

    // Save answer to Firebase
    _saveAnswer(
      subcategoryName: _currentSubcategoryName,
      questionKey: questionKey,
      questionText: question.question,
      legend: legend,
      value: chosenValue,
    );

    _goToNext();
  }

  /// Advances to the next question or subcategory, or finishes if all done.
  void _goToNext() {
    setState(() {
      // If there are more questions in the current subcategory
      if (_currentQuestionIndex < _currentQuestionKeys.length - 1) {
        _currentQuestionIndex++;
      } else {
        // Move to the next subcategory
        if (_currentSubcategoryIndex < _subcategoryNames.length - 1) {
          _currentSubcategoryIndex++;
          _currentQuestionIndex = 0;
        } else {
          // All subcategories done
          _saveFinalData();
          _endQuestion();
        }
      }
    });
  }

  /// Moves to the previous question if possible.
  void _goToPrevious() {
    setState(() {
      if (_currentQuestionIndex > 0) {
        _currentQuestionIndex--;
      } else {
        // If we’re at the first question of this subcategory,
        // move to the previous subcategory (if any).
        if (_currentSubcategoryIndex > 0) {
          _currentSubcategoryIndex--;
          // Jump to the last question of that subcategory
          _currentQuestionIndex =
              _subcategories[_currentSubcategoryName]!.questions.length - 1;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Current question object
    final question = _currentQuestion;

    // Calculate total number of questions across all subcategories
    int totalQuestions = _subcategories.values.fold(
      0,
      (sum, subcat) => sum + subcat.questions.length,
    );

    // Determine how many questions we have already passed through
    int questionsSoFar = 0;
    for (int i = 0; i < _currentSubcategoryIndex; i++) {
      questionsSoFar += _subcategories[_subcategoryNames[i]]!.questions.length;
    }
    // Add the current question index (plus 1 for 0-based indexing)
    questionsSoFar += (_currentQuestionIndex + 1);

    double progressBarValue =
        (totalQuestions == 0) ? 0.0 : (questionsSoFar / totalQuestions);

    // For diamond icons, we create a list of total length = totalQuestions
    // We'll color them if index < questionsSoFar.
    // (But you can keep your approach if you prefer.)
    List<Widget> diamondIcons = List.generate(totalQuestions, (index) {
      return Image.asset(
        'assets/diamond.png',
        height: 15,
        width: 15,
        color: index < questionsSoFar ? Colors.blue : Colors.grey,
      );
    });

    // Currently selected answer (if any)
    final selectedValue = (question != null && _currentQuestionKey != null)
        ? _selectedAnswers[_currentSubcategoryName]![_currentQuestionKey!]
        : null;

    return Scaffold(
      backgroundColor: AppColors.lighterGreen,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with back button and title
            Container(
              height: 120,
              color: AppColors.lightGreen,
              child: Row(
                children: [
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
                          // Optional: Show current subcategory name
                          if (_currentSubcategoryName.isNotEmpty)
                            Text(
                              _currentSubcategoryName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
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

            // Display current question text
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

            // Display answer choices as radio buttons
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
                          _selectedAnswers[_currentSubcategoryName]![
                              _currentQuestionKey!] = value;
                        });
                        // Slight delay, then move on
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
