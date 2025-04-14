import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/models/questions.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:intl/intl.dart';
import 'package:serenity_mobile/screens/doctor_dashboard.dart';

class Subcategory {
  final String name;
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
  List<String> _userConditions = [];

  // subcategories => Map of subcategory name to Subcategory object
  Map<String, Subcategory> _subcategories = {};
  List<String> _subcategoryNames = [];

  int _currentSubcategoryIndex = 0;
  int _currentQuestionIndex = 0;

  // For each subcategory, map questionKey -> selected answer text (legend)
  Map<String, Map<String, String?>> _selectedAnswers = {};
  // Tracks the numeric total of each subcategory
  Map<String, double> _subcategoryTotals = {};
  // Tracks the overall total for all subcategories in the condition
  double _overallTotal = 0.0;

  // The session timestamp (e.g., 2025-04-14_16:42:44)
  late String _currentSessionTimestamp;

  // We'll store the main questionnaire title (e.g., "Hamilton Anxiety Rating Scale (HAM-A)")
  // so that we can later write it under {condition}/{timestamp}/questionnaireTitle
  String _questionnaireTitle = "Initial Questionnaire";

  @override
  void initState() {
    super.initState();
    // Create the session timestamp once
    _currentSessionTimestamp = _getFormattedTimestamp().replaceAll(' ', '_');
    _fetchUserConditionsAndCombineQuestions();
  }

  String _getFormattedTimestamp() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
  }

  /// Converts dynamic data to a list.
  List<dynamic> _convertToList(dynamic data) {
    if (data is List) return data;
    if (data is Map) return data.values.toList();
    return [];
  }

  /// Fetch the user's conditions from:
  /// administrator/users/{userUID}/conditions
  /// Then load questionnaire data from defaultQuestionnaires/{Condition}.
  Future<void> _fetchUserConditionsAndCombineQuestions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userUID = user.uid;
    final userRef = _dbRef.child('administrator/users/$userUID/conditions');
    final userEvent = await userRef.once();

    if (!userEvent.snapshot.exists) {
      print("No conditions found for user");
      return;
    }

    final conditionData = userEvent.snapshot.value;
    if (conditionData is List && conditionData.isNotEmpty) {
      _userConditions = conditionData.map((c) => c.toString().trim()).toList();
    } else if (conditionData is Map && conditionData.isNotEmpty) {
      _userConditions = conditionData.values
          .map((c) => c.toString().trim())
          .toList()
          .cast<String>();
    }

    print("User conditions: $_userConditions");
    if (_userConditions.isEmpty) return;

    await _combineAllConditionQuestions();
    setState(() {
      _currentSubcategoryIndex = 0;
      _currentQuestionIndex = 0;
    });
  }

  /// Combines all questionnaires for each condition from:
  /// defaultQuestionnaires/{Condition}/{Survey Title}/{Subcategory}/{Question}
  ///
  /// Instead of merging everything into one big key, we store:
  /// - _questionnaireTitle (the "Survey Title"), e.g. "Hamilton Anxiety Rating Scale (HAM-A)"
  /// - Subcategory name alone, e.g. "Anxious Mood", "Autonomic Symptoms", etc.
  Future<void> _combineAllConditionQuestions() async {
    _subcategories.clear();
    _subcategoryNames.clear();
    _selectedAnswers.clear();
    _subcategoryTotals.clear();
    _overallTotal = 0.0;

    // We only handle the first condition here for demonstration,
    // or you can adapt this loop to handle multiple conditions.
    // For simplicity, let's assume we only load from the first condition in the list.
    // If you want to handle multiple conditions, you might structure your data differently.
    if (_userConditions.isEmpty) return;

    final condition = _userConditions.first;
    // e.g. defaultQuestionnaires/Anxiety
    final conditionRef =
        _dbRef.child('administrator/defaultQuestionnaires/$condition');
    final conditionEvent = await conditionRef.once();

    if (!conditionEvent.snapshot.exists ||
        conditionEvent.snapshot.value is! Map) {
      print("No default questionnaire data for condition: $condition");
      return;
    }

    final conditionMap =
        Map<dynamic, dynamic>.from(conditionEvent.snapshot.value as Map);
    print(
        "Found questionnaire data for $condition, keys: ${conditionMap.keys}");

    // We'll only handle one "Survey Title" in this example,
    // or if there's multiple, you can decide how to handle them.
    // For instance, if the user has "Hamilton Anxiety Rating Scale (HAM-A)"
    // and another scale, you'd loop over them. Let's assume there's only one.
    var firstTitleKey = conditionMap.keys.first;
    _questionnaireTitle = firstTitleKey.toString();

    final titleData = conditionMap[firstTitleKey];
    if (titleData is Map) {
      final titleMap = Map<dynamic, dynamic>.from(titleData);
      // Each key in here is a subcategory, e.g. "Anxious Mood", "Autonomic Symptoms", etc.
      for (var rawSubcatKey in titleMap.keys) {
        final subcatData = titleMap[rawSubcatKey];
        if (subcatData is Map) {
          final subcatMap = Map<dynamic, dynamic>.from(subcatData);
          final subcatName = rawSubcatKey.toString().trim();

          // Build the Subcategory object
          Map<String, Questions> questionsMap = {};
          for (var rawQuestionKey in subcatMap.keys) {
            final questionData = subcatMap[rawQuestionKey];
            if (questionData is Map &&
                questionData.containsKey('question') &&
                questionData.containsKey('legend') &&
                questionData.containsKey('value')) {
              final questionText = questionData['question'] as String;
              final legends = _convertToList(questionData['legend']);
              final values = _convertToList(questionData['value']);

              if (legends.length == values.length) {
                List<Map<String, dynamic>> choices = [];
                for (int i = 0; i < legends.length; i++) {
                  choices.add({
                    'text': legends[i].toString(),
                    'value': double.tryParse(values[i].toString()) ?? 0.0,
                  });
                }
                questionsMap[rawQuestionKey.toString()] = Questions(
                  question: questionText,
                  choices: choices,
                );
              }
            }
          }

          // Save the subcategory
          _subcategories[subcatName] =
              Subcategory(name: subcatName, questions: questionsMap);
        }
      }
    }

    // Now we have subcategories that are named simply "Anxious Mood", "Fears", etc.
    // Create the lists and maps we need for indexing and storing selected answers.
    _subcategoryNames = _subcategories.keys.toList();
    print("Subcategories found: $_subcategoryNames");
    for (var subcat in _subcategoryNames) {
      _subcategoryTotals[subcat] = 0.0;
      _selectedAnswers[subcat] = {};
    }
  }

  // The subcategory name from the list of subcategory keys
  String get _currentSubcategoryKey {
    if (_subcategoryNames.isNotEmpty &&
        _currentSubcategoryIndex < _subcategoryNames.length) {
      return _subcategoryNames[_currentSubcategoryIndex];
    }
    return "";
  }

  Subcategory? get _currentSubcategory {
    return _subcategories[_currentSubcategoryKey];
  }

  // The list of question keys for the current subcategory
  List<String> get _currentQuestionKeys {
    return _currentSubcategory?.questions.keys.toList() ?? [];
  }

  // The current question object
  Questions? get _currentQuestion {
    final keys = _currentSubcategory?.questions.keys.toList();
    if (keys != null && _currentQuestionIndex < keys.length) {
      return _currentSubcategory?.questions[keys[_currentQuestionIndex]];
    }
    return null;
  }

  // The current question key
  String? get _currentQuestionKey {
    final keys = _currentSubcategory?.questions.keys.toList();
    if (keys != null && _currentQuestionIndex < keys.length) {
      return keys[_currentQuestionIndex];
    }
    return null;
  }

  /// Save an individual answer under:
  /// administrator/users/{userUID}/all_answers/{Condition}/{SessionTimestamp}/{Subcategory}/{QuestionKey}
  void _saveAnswer({
    required String condition, // e.g. "Anxiety"
    required String subcatName, // e.g. "Anxious Mood"
    required String questionKey,
    required String questionText,
    required String legend,
    required double value,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Build the path with the condition first, then the timestamp, then subcategory, questionKey
    final answersRef = _dbRef.child(
      'administrator/users/${user.uid}/all_answers/$condition/$_currentSessionTimestamp/$subcatName/$questionKey',
    );

    await answersRef.set({
      'question': questionText,
      'legend': legend,
      'value': value,
    });
    print("Saved answer for [$questionKey] under [$condition -> $subcatName]");
  }

  void _onAnswerSelected(String? legend) {
    if (legend == null) return;
    final question = _currentQuestion;
    final questionKey = _currentQuestionKey;
    if (question == null || questionKey == null) return;

    final subcatName = _currentSubcategoryKey;
    if (subcatName.isEmpty) return;

    double chosenValue = 0.0;
    for (var choice in question.choices) {
      if (choice['text'] == legend) {
        chosenValue = choice['value'];
        break;
      }
    }

    // Store the legend locally
    _selectedAnswers[subcatName]![questionKey] = legend;
    // Update subcategory total
    _subcategoryTotals[subcatName] =
        (_subcategoryTotals[subcatName] ?? 0.0) + chosenValue;
    // Update overall total
    _overallTotal += chosenValue;

    // For demonstration, we'll assume the user has only one condition, e.g. Anxiety
    final condition =
        _userConditions.isNotEmpty ? _userConditions.first : "UnknownCondition";

    // Save the answer to the DB
    _saveAnswer(
      condition: condition,
      subcatName: subcatName,
      questionKey: questionKey,
      questionText: question.question,
      legend: legend,
      value: chosenValue,
    );

    // Move on to the next question
    _goToNext();
  }

  void _goToNext() {
    setState(() {
      if (_currentQuestionIndex < _currentQuestionKeys.length - 1) {
        _currentQuestionIndex++;
      } else {
        if (_currentSubcategoryIndex < _subcategoryNames.length - 1) {
          _currentSubcategoryIndex++;
          _currentQuestionIndex = 0;
        } else {
          // Save final data for the entire condition
          _saveFinalData();
          _endQuestion();
        }
      }
    });
  }

  void _goToPrevious() {
    setState(() {
      if (_currentQuestionIndex > 0) {
        _currentQuestionIndex--;
      } else if (_currentSubcategoryIndex > 0) {
        _currentSubcategoryIndex--;
        _currentQuestionIndex =
            _subcategories[_currentSubcategoryKey]!.questions.length - 1;
      }
    });
  }

  /// Once all questions are answered, store subcategory totals, total_value,
  /// and questionnaireTitle under the node:
  /// {Condition}/{SessionTimestamp}
  Future<void> _saveFinalData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_userConditions.isEmpty) return;

    final condition = _userConditions.first;
    final userUID = user.uid;
    final sessionPath =
        'administrator/users/$userUID/all_answers/$condition/$_currentSessionTimestamp';
    final sessionRef = _dbRef.child(sessionPath);

    // Use .toList() to avoid concurrent modification issues.
    for (String subcatName in _subcategoryTotals.keys.toList()) {
      final subcatTotal = _subcategoryTotals[subcatName] ?? 0.0;
      await sessionRef.child('$subcatName/subcategory_total').set(subcatTotal);
    }

    // Write aggregated data.
    await sessionRef.child('questionnaireTitle').set(_questionnaireTitle);
    await sessionRef.child('total_value').set(_overallTotal);
    await sessionRef.child('timestamp').set(_getFormattedTimestamp());

    // Mark questionnaire as completed.
    final userRef = _dbRef.child('administrator/users/$userUID');
    await userRef.update({'questionnaire_completed': true});
    print(
        "Final data saved for condition = $condition, session = $_currentSessionTimestamp");
  }

  void _endQuestion() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Well done!"),
          content: const Text(
            "Thank you for answering the initial questionnaire(s). "
            "This data will be used upon diagnosing your condition.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => DoctorDashboard()),
                );
                // Reset local states
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
    if (_userConditions.isEmpty || _subcategoryNames.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final question = _currentQuestion;
    final questionKey = _currentQuestionKey;
    final totalQuestions = _subcategories.values
        .fold(0, (sum, subcat) => sum + subcat.questions.length);

    // Figure out how many questions the user has answered so far
    int questionIndexSoFar = 0;
    for (int i = 0; i < _currentSubcategoryIndex; i++) {
      questionIndexSoFar +=
          _subcategories[_subcategoryNames[i]]!.questions.length;
    }
    questionIndexSoFar += (_currentQuestionIndex + 1);

    final progressBarValue =
        totalQuestions == 0 ? 0.0 : (questionIndexSoFar / totalQuestions);

    final subcatName = _currentSubcategoryKey;
    final selectedValue = (subcatName.isNotEmpty && questionKey != null)
        ? _selectedAnswers[subcatName]![questionKey]
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
                  child: Stack(
                    children: [
                      Positioned(
                        top: 40,
                        left: 8,
                        child: Container(
                          // Wrapped in Container to match questionnaires.dart
                          decoration: const BoxDecoration(
                            color: AppColors.lightGreen,
                            borderRadius: BorderRadius.zero,
                          ),
                          child: IconButton(
                            // Changed to IconButton
                            onPressed:
                                questionIndexSoFar > 1 ? _goToPrevious : null,
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 40,
                        left: 80,
                        right: 80,
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
                            if (subcatName.isNotEmpty)
                              Text(
                                subcatName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress bar (visualizing the question-by-question progress)
                const SizedBox(height: 2),
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
                    // If you want to display diamonds or other UI elements, add them here
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

                // Radio buttons for each choice
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
                          onChanged: (String? value) {
                            setState(() {
                              _selectedAnswers[subcatName]![questionKey!] =
                                  value;
                            });
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
