import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/models/questions.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:intl/intl.dart';
import 'homepage.dart';

class Subcategory {
  final String name;
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
  List<String> _userConditions = [];
  Map<String, Subcategory> _subcategories = {};
  List<String> _subcategoryNames = [];
  int _currentSubcategoryIndex = 0;
  int _currentQuestionIndex = 0;
  Map<String, Map<String, String?>> _selectedAnswers = {};
  Map<String, double> _subcategoryTotals = {};
  double _overallTotal = 0.0;
  String _currentSessionTimestamp = '';

  // Stores the questionnaire title per condition (e.g., "Hamilton Anxiety Rating Scale (HAM-A)")
  Map<String, String> _questionnaireTitles = {};

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

  /// Searches all doctors (under administrator/doctors) to see if the current user is a patient.
  /// Since the mypatients node uses push IDs, we iterate through its children and
  /// check if any child's 'patientID' field matches the current user's UID.
  Future<Map<dynamic, dynamic>?> _findDoctorQuestionnaires() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final userUID = user.uid;

    // Look under 'administrator/doctors'
    final doctorsRef = _dbRef.child('administrator/doctors');
    final doctorsSnapshot = await doctorsRef.once();
    if (!doctorsSnapshot.snapshot.exists) return null;

    final doctorsData =
        Map<dynamic, dynamic>.from(doctorsSnapshot.snapshot.value as Map);

    // Iterate over each doctor.
    for (var docKey in doctorsData.keys) {
      final docData = doctorsData[docKey];
      if (docData is Map && docData['mypatients'] is Map) {
        final mypatientsMap =
            Map<dynamic, dynamic>.from(docData['mypatients'] as Map);
        // Iterate over the children of mypatients.
        for (var pushKey in mypatientsMap.keys) {
          final childData = mypatientsMap[pushKey];
          if (childData is Map && childData['patientID'] == userUID) {
            print("User found under doctor $docKey via pushKey $pushKey");
            // Modified to look for activeQuestionnaires instead of savedQuestionnaires.
            if (docData['activeQuestionnaires'] is Map) {
              return Map<dynamic, dynamic>.from(
                  docData['activeQuestionnaires'] as Map);
            }
          }
        }
      }
    }
    print("No matching doctor found for user $userUID");
    return null;
  }

  /// Fetches the user's conditions and then loads questionnaire data
  /// only from the doctor's activeQuestionnaires node.
  Future<void> _fetchUserConditionsAndCombineQuestions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userUID = user.uid;
    final userRef = _dbRef.child('administrator/users/$userUID/conditions');
    final userEvent = await userRef.once();

    if (!userEvent.snapshot.exists) return;

    var conditionData = userEvent.snapshot.value;
    if (conditionData is List && conditionData.isNotEmpty) {
      _userConditions = List<String>.from(conditionData);
    } else if (conditionData is Map && conditionData.isNotEmpty) {
      _userConditions = List<String>.from(conditionData.values);
    }
    print("User conditions: $_userConditions");
    if (_userConditions.isEmpty) return;

    // Attempt to load doctor's questionnaires only.
    final doctorQuestionnaires = await _findDoctorQuestionnaires();
    if (doctorQuestionnaires != null) {
      print("Doctor questionnaires keys: ${doctorQuestionnaires.keys}");
      await _combineDoctorQuestionnaires(doctorQuestionnaires);
    } else {
      print("No active questionnaires found for user from doctor's list.");
    }

    setState(() {
      _currentSubcategoryIndex = 0;
      _currentQuestionIndex = 0;
    });
  }

  /// Combines questionnaires from the doctor's activeQuestionnaires node.
  /// Uses a case-insensitive search for matching condition keys.
  Future<void> _combineDoctorQuestionnaires(
      Map<dynamic, dynamic> doctorQuestionnaires) async {
    _subcategories.clear();
    _subcategoryNames.clear();
    _selectedAnswers.clear();
    _subcategoryTotals.clear();
    _overallTotal = 0.0;
    _questionnaireTitles.clear();

    // Loop through each condition that the user has.
    for (String condition in _userConditions) {
      // Find a matching key in doctorQuestionnaires (case-insensitive, trimmed).
      final matchingConditionKey = doctorQuestionnaires.keys.firstWhere(
        (k) =>
            k.toString().toLowerCase().trim() == condition.toLowerCase().trim(),
        orElse: () => null,
      );

      if (matchingConditionKey != null) {
        print(
            "Found matching condition key: $matchingConditionKey for user condition: $condition");
        final conditionData = doctorQuestionnaires[matchingConditionKey];
        if (conditionData is Map) {
          // Expected structure:
          // {
          //   "Hamilton Anxiety Rating Scale (HAM-A)": {
          //       "Anxious Mood": { ... },
          //       "Autonomic Symptoms": { ... },
          //       ...
          //   }
          // }
          String questionnaireTitle = "";
          Map<dynamic, dynamic> questionnaireData = {};

          conditionData.forEach((key, value) {
            if (questionnaireTitle.isEmpty) {
              questionnaireTitle = key.toString();
              if (value is Map) {
                questionnaireData = Map<dynamic, dynamic>.from(value);
              }
            }
          });

          print(
              "Doctor questionnaire title for condition $condition: $questionnaireTitle");
          _questionnaireTitles[condition] = questionnaireTitle;

          // Parse each subcategory.
          for (var rawSubcatKey in questionnaireData.keys) {
            final subcatData = questionnaireData[rawSubcatKey];
            if (subcatData is Map) {
              final trimmedSubcatKey = rawSubcatKey.toString().trim();
              final mergedKey = "$condition - $trimmedSubcatKey";
              Map<String, Questions> questionsMap = {};
              final subcatMap = Map<dynamic, dynamic>.from(subcatData);

              for (var rawQuestionKey in subcatMap.keys) {
                final questionData = subcatMap[rawQuestionKey];
                if (questionData is Map) {
                  if (questionData.containsKey('question') &&
                      questionData.containsKey('legend') &&
                      questionData.containsKey('value')) {
                    final questionText = questionData['question'] as String;
                    final legends =
                        List<dynamic>.from(questionData['legend'] as List);
                    final values =
                        List<dynamic>.from(questionData['value'] as List);

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
              }
              _subcategories[mergedKey] =
                  Subcategory(name: mergedKey, questions: questionsMap);
            }
          }
        }
      } else {
        print(
            "No matching doctor questionnaire found for condition: $condition");
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

  /// Saves an individual answer.
  /// The answer is stored under:
  /// administrator/users/{userUID}/all_answers/{condition}/{timestamp}/{subcategoryName}/{questionKey}
  /// The questionnaire title is stored as a property at the same level as the subcategory nodes.
  void _saveAnswer(
    String mergedSubcatKey,
    String questionKey,
    String questionText,
    String legend,
    double value,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final parts = mergedSubcatKey.split(" - ");
    final condition = parts[0].trim();
    final subcategoryName =
        parts.length > 1 ? parts[1].trim() : parts[0].trim();
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

    _saveAnswer(mergedKey, questionKey, question.question, legend, chosenValue);
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

  void _endQuestion() {
    _saveAllData();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Well done!"),
          content: const Text("Thank you for answering the weekly questions."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Create a new HomePage instance and force refresh
                final newHomePage = HomePage(
                  key: UniqueKey(),
                  currentIndex: 0,
                );
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => newHomePage,
                  ),
                  (route) => false, // This removes all previous routes
                );
                // Clear all the questionnaire data
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

  Future<void> _saveAllData() async {
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

    for (String condition in subcatTotalsByCondition.keys) {
      final questionnaireTitle =
          _questionnaireTitles[condition] ?? "Weekly Questionnaire";
      final sessionRef = _dbRef.child(
          'administrator/users/$userUID/all_answers/$condition/$_currentSessionTimestamp');

      await sessionRef.child('questionnaireTitle').set(questionnaireTitle);

      final subMap = subcatTotalsByCondition[condition]!;
      for (String subcatName in subMap.keys) {
        await sessionRef
            .child('$subcatName/subcategory_total')
            .set(subMap[subcatName]);
      }
      await sessionRef.child('total_value').set(conditionTotals[condition]);
      await sessionRef.child('timestamp').set(_getFormattedTimestamp());
    }

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

    for (String c in _userConditions) {
      if (!previouslyAnswered.contains(c)) {
        previouslyAnswered.add(c);
      }
    }

    await lastAnsweredRef.set({
      'conditions': previouslyAnswered,
      'timestamp': _getFormattedTimestamp(),
    });
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

    int questionIndexSoFar = 0;
    for (int i = 0; i < _currentSubcategoryIndex; i++) {
      questionIndexSoFar +=
          _subcategories[_subcategoryNames[i]]!.questions.length;
    }
    questionIndexSoFar += (_currentQuestionIndex + 1);

    final progressBarValue =
        totalQuestions == 0 ? 0.0 : (questionIndexSoFar / totalQuestions);
    final mergedKey = _currentSubcategoryKey;
    final selectedValue = mergedKey.isNotEmpty && questionKey != null
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
                Container(
                  height: 120,
                  color: AppColors.lightGreen,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 40,
                        left: 8,
                        child: Container(
                          // Wrapped in Container to isolate styles
                          decoration: const BoxDecoration(
                            color: AppColors.lightGreen,
                            borderRadius: BorderRadius.zero,
                          ),
                          child: IconButton(
                            // Changed to IconButton instead of ElevatedButton
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
                          children: [
                            const Text(
                              "Weekly Questions",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                          color: index < questionIndexSoFar
                              ? Colors.blue
                              : Colors.grey,
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
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        child: RadioListTile<String>(
                          tileColor: AppColors.dirtyWhite,
                          title: Text(choice['text']),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 30),
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
