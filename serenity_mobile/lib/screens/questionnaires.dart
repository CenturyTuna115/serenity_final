import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/models/questions.dart'; // Adjust to your file path
import 'package:serenity_mobile/resources/colors.dart'; // Adjust to your file path
import 'package:intl/intl.dart';
import 'homepage.dart'; // Or wherever your main/home page is

/// Simple class to hold subcategory name and questions.
class Subcategory {
  final String name; // e.g. "Anxious Mood"
  // Map of questionKey -> Questions object
  final Map<String, Questions> questions;

  Subcategory({required this.name, required this.questions});
}

class Questionnaires extends StatefulWidget {
  const Questionnaires({Key? key}) : super(key: key);

  @override
  _QuestionnairesState createState() => _QuestionnairesState();
}

class _QuestionnairesState extends State<Questionnaires> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Subcategories loaded from Firebase
  Map<String, Subcategory> _subcategories = {};
  List<String> _subcategoryNames = [];
  int _currentSubcategoryIndex = 0;

  // Current question index within the selected subcategory
  int _currentQuestionIndex = 0;

  // Store user answers in a nested map:
  // _selectedAnswers[subcategoryName][questionKey] = chosenLegend
  Map<String, Map<String, String?>> _selectedAnswers = {};

  // Keep track of each subcategory's total and the overall total
  Map<String, double> _subcategoryTotals = {};
  double _overallTotal = 0.0;

  // The user’s condition and possibly doctor ID (if needed)
  String? _userCondition;
  String? _doctorId;

  @override
  void initState() {
    super.initState();
    _fetchUserConditionAndQuestions();
  }

  /// Utility method to generate a timestamp in UTC+8.
  String _getFormattedTimestamp() {
    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    // Convert local time to UTC, then add +8 hours
    return formatter.format(now.toUtc().add(const Duration(hours: 8)));
  }

  /// Fetches the user's condition and assigned doctor, then loads questions.
  void _fetchUserConditionAndQuestions() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("No user logged in.");
      return;
    }

    String userUID = user.uid;

    // 1) Fetch user condition
    DatabaseReference userRef =
        _dbRef.child('administrator/users/$userUID/conditions');
    DatabaseEvent userEvent = await userRef.once();

    if (userEvent.snapshot.exists) {
      var userConditionData = userEvent.snapshot.value;
      if (userConditionData is List && userConditionData.isNotEmpty) {
        _userCondition = userConditionData[0];
        debugPrint("User condition: $_userCondition");

        // 2) Optionally fetch assigned doctor if needed
        //    (If your logic requires a doctor ID, fetch it here.
        //     Otherwise skip if you only read from defaultQuestionnaires.)
        // For example:
        /*
        DatabaseReference myDoctorsRef =
            _dbRef.child('administrator/users/$userUID/mydoctors');
        DatabaseEvent doctorEvent = await myDoctorsRef.once();
        if (doctorEvent.snapshot.exists) {
          var doctorData = doctorEvent.snapshot.value as Map<dynamic, dynamic>;
          if (doctorData.isNotEmpty) {
            var firstDoctor = doctorData.values.first;
            _doctorId = firstDoctor['doctorId'];
            debugPrint("Assigned Doctor ID: $_doctorId");
          }
        }
        */

        // Now load the subcategories & questions
        fetchQuestionsBasedOnCondition();
      } else {
        debugPrint("User condition data is empty or not a list.");
      }
    } else {
      debugPrint("Failed to fetch user condition data.");
    }
  }

  /// Loads all subcategories and questions based on the user's condition
  /// from, for example: /administrator/doctors/{doctorId}/activeQuestionnaires/{condition}/{condition}
  /// or /administrator/defaultQuestionnaires/{condition}/{condition}
  void fetchQuestionsBasedOnCondition() async {
    if (_userCondition == null) {
      debugPrint("No user condition. Cannot fetch questions.");
      return;
    }

    // Example path if using default questionnaires:
    DatabaseReference baseRef = _dbRef.child(
      'administrator/defaultQuestionnaires/$_userCondition/$_userCondition',
    );

    DatabaseEvent baseEvent = await baseRef.once();
    if (baseEvent.snapshot.exists && baseEvent.snapshot.value is Map) {
      final categoriesMap = Map<dynamic, dynamic>.from(
        baseEvent.snapshot.value as Map<dynamic, dynamic>,
      );

      Map<String, Subcategory> tempSubcategories = {};

      // Loop through subcategory names (e.g., "Anxious Mood", "Autonomic Symptoms", etc.)
      for (var rawSubcatKey in categoriesMap.keys.toList()) {
        final subcatKey = rawSubcatKey.toString();
        final rawSubcatData = categoriesMap[rawSubcatKey];

        if (rawSubcatData is Map) {
          final subcatDataMap = Map<dynamic, dynamic>.from(rawSubcatData);
          Map<String, Questions> questionsMap = {};

          // Each subcategory can have multiple questions (keys: "Q1", "Q2", etc.)
          for (var rawQuestionKey in subcatDataMap.keys.toList()) {
            final questionKey = rawQuestionKey.toString();
            final questionData = subcatDataMap[rawQuestionKey];

            if (questionData is Map<dynamic, dynamic>) {
              if (questionData.containsKey('question') &&
                  questionData.containsKey('legend') &&
                  questionData.containsKey('value')) {
                String questionText = questionData['question'];
                List<dynamic> legends = questionData['legend'];
                List<dynamic> values = questionData['value'];

                // Validate the data
                if (legends.length == values.length) {
                  List<Map<String, dynamic>> choices = [];
                  for (int i = 0; i < legends.length; i++) {
                    String choiceText = legends[i].toString();
                    double score = double.tryParse(values[i].toString()) ?? 0.0;
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

      // Update state with the newly fetched subcategories
      setState(() {
        _subcategories = tempSubcategories;
        _subcategoryNames = _subcategories.keys.toList();

        // Initialize totals and selected answers for each subcategory
        for (var name in _subcategoryNames) {
          _subcategoryTotals[name] = 0.0;
          _selectedAnswers[name] = {};
        }

        // Start at the first subcategory, first question
        _currentSubcategoryIndex = 0;
        _currentQuestionIndex = 0;
      });
    } else {
      debugPrint("No questions found for condition: $_userCondition");
    }
  }

  /// Helper: returns the name of the current subcategory
  String get _currentSubcategoryName => (_subcategoryNames.isNotEmpty &&
          _currentSubcategoryIndex < _subcategoryNames.length)
      ? _subcategoryNames[_currentSubcategoryIndex]
      : '';

  /// Helper: returns the list of question keys for the current subcategory
  List<String> get _currentQuestionKeys {
    if (_subcategories.containsKey(_currentSubcategoryName)) {
      return _subcategories[_currentSubcategoryName]!.questions.keys.toList();
    }
    return [];
  }

  /// Helper: returns the current Questions object (if any)
  Questions? get _currentQuestion {
    if (_subcategories.containsKey(_currentSubcategoryName)) {
      var subcat = _subcategories[_currentSubcategoryName]!;
      var keys = subcat.questions.keys.toList();
      if (_currentQuestionIndex < keys.length) {
        String qKey = keys[_currentQuestionIndex];
        return subcat.questions[qKey];
      }
    }
    return null;
  }

  /// Helper: returns the current questionKey
  String? get _currentQuestionKey {
    if (_subcategories.containsKey(_currentSubcategoryName)) {
      var keys =
          _subcategories[_currentSubcategoryName]!.questions.keys.toList();
      if (_currentQuestionIndex < keys.length) {
        return keys[_currentQuestionIndex];
      }
    }
    return null;
  }

  /// Saves a single answer into Firebase at:
  /// /administrator/users/$userUID/all_answers/{condition}/{condition}/{subcategoryName}/{questionKey}
  void _saveAnswer(
    String condition,
    String subcategoryName,
    String questionKey,
    String questionText,
    String legend,
    double value,
  ) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String userUID = user.uid;

    DatabaseReference answersRef = _dbRef.child(
      'administrator/users/$userUID/all_answers/$condition/$condition/$subcategoryName/$questionKey',
    );

    await answersRef.set({
      'question': questionText,
      'legend': legend,
      'value': value,
    });
  }

  /// When the user completes all questions, save the subcategory totals,
  /// the overall total, and the final timestamp at:
  /// /all_answers/{condition}/{condition}/
  /// Also mark last_answered or anything else you want.
  void _saveFinalData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || _userCondition == null) return;

    String userUID = user.uid;
    String condition = _userCondition!;

    DatabaseReference conditionRef = _dbRef.child(
      'administrator/users/$userUID/all_answers/$condition/$condition',
    );

    // *** CRITICAL FIX ***
    // Copy the list before iterating to avoid ConcurrentModificationError
    final localSubcatNames = List<String>.from(_subcategoryNames);

    // 1) Save each subcategory total
    for (var subcatName in localSubcatNames) {
      double subTotal = _subcategoryTotals[subcatName] ?? 0.0;
      await conditionRef.child('$subcatName/subcategory_total').set(subTotal);
    }

    // 2) Save the overall total and timestamp
    await conditionRef.update({
      'total_value': _overallTotal,
      'timestamp': _getFormattedTimestamp(),
    });

    // 3) Optionally, save the last answered info
    DatabaseReference userRef = _dbRef.child(
      'administrator/users/$userUID/last_answered',
    );
    await userRef.set({
      'condition': condition,
      'timestamp': _getFormattedTimestamp(),
    });

    debugPrint("Final data saved under all_answers/$condition/$condition.");
  }

  /// Display a final dialog, then return to the homepage (or anywhere else).
  void _endQuestion() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Well done!"),
          content: const Text(
            "Thank you for answering the weekly questionnaire. This helps in monitoring your progress.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => HomePage()),
                );

                // Reset local state if you want to allow another pass
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

  /// Called when the user selects a radio button answer.
  /// Stores the selection, updates totals, and moves on.
  void _onAnswerSelected(String? legend) {
    if (legend == null) return;
    final question = _currentQuestion;
    final questionKey = _currentQuestionKey;
    if (question == null || questionKey == null) return;

    // Find the score value associated with this choice
    double chosenValue = 0.0;
    for (var choice in question.choices) {
      if (choice['text'] == legend) {
        chosenValue = choice['value'];
        break;
      }
    }

    // Store selection in memory
    _selectedAnswers[_currentSubcategoryName]![questionKey] = legend;

    // Update subcategory total
    _subcategoryTotals[_currentSubcategoryName] =
        (_subcategoryTotals[_currentSubcategoryName] ?? 0.0) + chosenValue;

    // Update overall total
    _overallTotal += chosenValue;

    // Save the answer to Firebase
    _saveAnswer(
      _userCondition!,
      _currentSubcategoryName,
      questionKey,
      question.question,
      legend,
      chosenValue,
    );

    // Move on to the next question or subcategory
    _goToNext();
  }

  /// Advances to the next question; if the current subcategory is done,
  /// move to the next subcategory. If everything is done, finalize.
  void _goToNext() {
    setState(() {
      // 1) Are there more questions in this subcategory?
      if (_currentQuestionIndex < _currentQuestionKeys.length - 1) {
        _currentQuestionIndex++;
      } else {
        // 2) Move to the next subcategory
        if (_currentSubcategoryIndex < _subcategoryNames.length - 1) {
          _currentSubcategoryIndex++;
          _currentQuestionIndex = 0;
        } else {
          // 3) All subcategories are answered
          _saveFinalData();
          _endQuestion();
        }
      }
    });
  }

  /// Moves to the previous question (if any).
  void _goToPrevious() {
    setState(() {
      if (_currentQuestionIndex > 0) {
        _currentQuestionIndex--;
      } else {
        // If we’re at the first question of this subcategory,
        // move to the previous subcategory (if any).
        if (_currentSubcategoryIndex > 0) {
          _currentSubcategoryIndex--;
          // Jump to the last question in that subcategory
          _currentQuestionIndex =
              _subcategories[_currentSubcategoryName]!.questions.length - 1;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The current question object
    final question = _currentQuestion;

    // Calculate overall progress
    int totalQuestions = _subcategories.values.fold(
      0,
      (sum, subcat) => sum + subcat.questions.length,
    );

    // Count how many questions we’ve already gone through
    int questionIndexSoFar = 0;
    for (int i = 0; i < _currentSubcategoryIndex; i++) {
      questionIndexSoFar +=
          _subcategories[_subcategoryNames[i]]!.questions.length;
    }
    // Add the current question index (plus 1 for zero-based)
    questionIndexSoFar += (_currentQuestionIndex + 1);

    double progressBarValue =
        (totalQuestions == 0) ? 0.0 : (questionIndexSoFar / totalQuestions);

    // For convenience, find the user’s current selection in memory
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
                  // Only enable "back" if we’re not on the very first question
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
                            "Weekly Questions",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Show current subcategory name (optional)
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

            // Progress bar
            const SizedBox(height: 2),
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

            const SizedBox(height: 20),

            // Display the question text
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

            // Display the answer choices as radio buttons
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
                          _selectedAnswers[_currentSubcategoryName]![
                              _currentQuestionKey!] = value;
                        });
                        // Slight delay, then process
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
