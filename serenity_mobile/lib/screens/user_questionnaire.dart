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
  Map<String, Subcategory> _subcategories = {};
  List<String> _subcategoryNames = [];
  int _currentSubcategoryIndex = 0;
  int _currentQuestionIndex = 0;
  Map<String, Map<String, String?>> _selectedAnswers = {};
  Map<String, double> _subcategoryTotals = {};
  double _overallTotal = 0.0;
  String _currentSessionTimestamp = '';

  @override
  void initState() {
    super.initState();
    _currentSessionTimestamp = _getFormattedTimestamp().replaceAll(' ', '_');
    _fetchUserConditionsAndCombineQuestions();
  }

  String _getFormattedTimestamp() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
  }

  Future<void> _fetchUserConditionsAndCombineQuestions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userUID = user.uid;
    final userRef = _dbRef.child('administrator/users/$userUID/conditions');
    final userEvent = await userRef.once();

    if (!userEvent.snapshot.exists) return;

    var conditionData = userEvent.snapshot.value;
    if (conditionData is List && conditionData.isNotEmpty) {
      _userConditions = conditionData.map((c) => c.toString().trim()).toList();
    } else if (conditionData is Map && conditionData.isNotEmpty) {
      _userConditions = conditionData.values
          .map((c) => c.toString().trim())
          .toList()
          .cast<String>();
    }

    if (_userConditions.isEmpty) return;

    await _combineAllConditionQuestions();
    setState(() {
      _currentSubcategoryIndex = 0;
      _currentQuestionIndex = 0;
    });
  }

  Future<void> _combineAllConditionQuestions() async {
    _subcategories.clear();
    _subcategoryNames.clear();
    _selectedAnswers.clear();
    _subcategoryTotals.clear();
    _overallTotal = 0.0;

    for (String condition in _userConditions) {
      final baseRef = _dbRef
          .child('administrator/defaultQuestionnaires/$condition/$condition');
      final baseEvent = await baseRef.once();

      if (baseEvent.snapshot.exists && baseEvent.snapshot.value is Map) {
        final categoriesMap = Map<dynamic, dynamic>.from(
          baseEvent.snapshot.value as Map<dynamic, dynamic>,
        );

        for (var rawSubcatKey in categoriesMap.keys) {
          final subcatData = categoriesMap[rawSubcatKey];
          if (subcatData is Map) {
            final trimmedSubcatKey = rawSubcatKey.toString().trim();
            final mergedKey = "$condition - $trimmedSubcatKey";
            final subcatMap = Map<dynamic, dynamic>.from(subcatData);

            Map<String, Questions> questionsMap = {};

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
                      choices.add({
                        'text': legends[i].toString(),
                        'value': double.tryParse(values[i].toString()) ?? 0.0
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

            _subcategories[mergedKey] = Subcategory(
              name: mergedKey,
              questions: questionsMap,
            );
          }
        }
      }
    }

    _subcategoryNames = _subcategories.keys.toList();
    for (var mergedKey in _subcategoryNames) {
      _subcategoryTotals[mergedKey] = 0.0;
      _selectedAnswers[mergedKey] = {};
    }
  }

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

  List<String> get _currentQuestionKeys {
    return _currentSubcategory?.questions.keys.toList() ?? [];
  }

  Questions? get _currentQuestion {
    final keys = _currentSubcategory?.questions.keys.toList();
    if (keys != null && _currentQuestionIndex < keys.length) {
      return _currentSubcategory?.questions[keys[_currentQuestionIndex]];
    }
    return null;
  }

  String? get _currentQuestionKey {
    final keys = _currentSubcategory?.questions.keys.toList();
    if (keys != null && _currentQuestionIndex < keys.length) {
      return keys[_currentQuestionIndex];
    }
    return null;
  }

  // Updated _saveAnswer: now the path uses the condition as the primary key,
  // then the session timestamp, then the subcategory, then the question.
  void _saveAnswer({
    required String mergedSubcatKey,
    required String questionKey,
    required String questionText,
    required String legend,
    required double value,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final parts = mergedSubcatKey.split(" - ");
    final condition = parts[0].trim();
    final subcategoryName =
        parts.length > 1 ? parts[1].trim() : mergedSubcatKey.trim();

    final answersRef = _dbRef.child(
      'administrator/users/${user.uid}/all_answers/$condition/$_currentSessionTimestamp/$subcategoryName/$questionKey',
    );

    await answersRef.set({
      'question': questionText,
      'legend': legend,
      'value': value,
    });
  }

  void _onAnswerSelected(String? legend) {
    if (legend == null) return;

    final question = _currentQuestion;
    final questionKey = _currentQuestionKey;
    final mergedKey = _currentSubcategoryKey;
    if (question == null || questionKey == null || mergedKey.isEmpty) return;

    double chosenValue = 0.0;
    for (var choice in question.choices) {
      if (choice['text'] == legend) {
        chosenValue = choice['value'];
        break;
      }
    }

    _selectedAnswers[mergedKey]![questionKey] = legend;
    _subcategoryTotals[mergedKey] =
        (_subcategoryTotals[mergedKey] ?? 0.0) + chosenValue;
    _overallTotal += chosenValue;

    _saveAnswer(
      mergedSubcatKey: mergedKey,
      questionKey: questionKey,
      questionText: question.question,
      legend: legend,
      value: chosenValue,
    );

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
      } else {
        if (_currentSubcategoryIndex > 0) {
          _currentSubcategoryIndex--;
          _currentQuestionIndex =
              _subcategories[_currentSubcategoryKey]!.questions.length - 1;
        }
      }
    });
  }

  // Updated _saveFinalData: for each condition, we create a session node
  // under the condition key and then store subcategory totals and overall totals.
  Future<void> _saveFinalData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userUID = user.uid;
    Map<String, Map<String, double>> subcatTotalsByCondition = {};
    Map<String, double> conditionTotals = {};

    for (String mergedKey in _subcategoryTotals.keys) {
      final parts = mergedKey.split(" - ");
      final condition = parts[0].trim();
      final subcatName = parts.length > 1 ? parts[1].trim() : mergedKey.trim();
      final subTotal = _subcategoryTotals[mergedKey] ?? 0.0;

      subcatTotalsByCondition.putIfAbsent(condition, () => {});
      conditionTotals.putIfAbsent(condition, () => 0.0);

      subcatTotalsByCondition[condition]![subcatName] = subTotal;
      conditionTotals[condition] = conditionTotals[condition]! + subTotal;
    }

    // For each condition, save the subcategory totals, overall total, and timestamp
    for (String condition in subcatTotalsByCondition.keys) {
      final sessionRef = _dbRef.child(
        'administrator/users/$userUID/all_answers/$condition/$_currentSessionTimestamp',
      );
      final subMap = subcatTotalsByCondition[condition]!;
      for (String subcatName in subMap.keys) {
        await sessionRef
            .child('$subcatName/subcategory_total')
            .set(subMap[subcatName]);
      }
      await sessionRef.child('total_value').set(conditionTotals[condition]);
      await sessionRef.child('timestamp').set(_getFormattedTimestamp());
    }

    final userRef = _dbRef.child('administrator/users/$userUID');
    await userRef.update({'questionnaire_completed': true});
  }

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

    final totalQuestions = _subcategories.values.fold(
      0,
      (sum, subcat) => sum + subcat.questions.length,
    );

    int questionsSoFar = 0;
    for (int i = 0; i < _currentSubcategoryIndex; i++) {
      questionsSoFar += _subcategories[_subcategoryNames[i]]!.questions.length;
    }
    questionsSoFar += (_currentQuestionIndex + 1);

    final progressBarValue =
        totalQuestions == 0 ? 0.0 : (questionsSoFar / totalQuestions);
    final mergedKey = _currentSubcategoryKey;
    final selectedValue = mergedKey.isNotEmpty && questionKey != null
        ? _selectedAnswers[mergedKey]![questionKey]
        : null;

    return Scaffold(
      backgroundColor: AppColors.lighterGreen,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 120,
              color: AppColors.lightGreen,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: ElevatedButton(
                      onPressed: questionsSoFar > 1 ? _goToPrevious : null,
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
                  children: List.generate(totalQuestions, (index) {
                    return Image.asset(
                      'assets/diamond.png',
                      height: 15,
                      width: 15,
                      color: index < questionsSoFar ? Colors.blue : Colors.grey,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
