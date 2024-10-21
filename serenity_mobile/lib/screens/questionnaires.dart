import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/models/questions.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:intl/intl.dart';
import 'homepage.dart';

class Questionnaires extends StatefulWidget {
  const Questionnaires({super.key});

  @override
  _QuestionnairesState createState() => _QuestionnairesState();
}

class _QuestionnairesState extends State<Questionnaires> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Questions> _questions = [];
  int _currentQuestionIndex = 0;
  Map<int, String?> _selectedAnswers = {};
  double _totalValue = 0.0;
  String _answerSetKey = '';
  String? _userCondition; // Store the condition here

  @override
  void initState() {
    super.initState();
    _initializeAnswerSet();
    _fetchUserConditionAndQuestions();
  }

  void _initializeAnswerSet() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String userUID = user.uid;

      // Fetch user conditions
      DatabaseReference conditionsRef =
          _dbRef.child('administrator/users/$userUID/conditions');
      DatabaseEvent conditionsEvent = await conditionsRef.once();

      if (conditionsEvent.snapshot.exists) {
        var conditionsData = conditionsEvent.snapshot.value;

        if (conditionsData is List && conditionsData.isNotEmpty) {
          _userCondition = conditionsData[0]; // Assume the first condition
          DatabaseReference userAnswersRef = _dbRef
              .child('administrator/users/$userUID/all_answers/$_userCondition')
              .push();
          _answerSetKey = userAnswersRef.key!;
        }
      }
    }
  }

  String _getFormattedTimestamp() {
    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formatted = formatter.format(
      now
          .toUtc()
          .add(const Duration(hours: 8)), // Convert to Philippine Time (UTC+8)
    );
    return formatted;
  }

  void _fetchUserConditionAndQuestions() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String userUID = user.uid;
      DatabaseReference userRef =
          _dbRef.child('administrator/users/$userUID/conditions');
      DatabaseEvent userEvent = await userRef.once();

      if (userEvent.snapshot.exists) {
        var userConditionData = userEvent.snapshot.value;
        if (userConditionData is List && userConditionData.isNotEmpty) {
          _userCondition = userConditionData[0];
          print("User condition: $_userCondition");

          DatabaseEvent doctorsEvent =
              await _dbRef.child('administrator/doctors').once();

          if (doctorsEvent.snapshot.exists) {
            var doctorsData = doctorsEvent.snapshot.value;

            if (doctorsData is Map) {
              Map<String, dynamic> doctors =
                  Map<String, dynamic>.from(doctorsData);
              print("Doctors data fetched successfully.");

              for (var doctorId in doctors.keys) {
                var doctorData = doctors[doctorId];
                print(
                    "Checking doctor: $doctorId with specialization ${doctorData['specialization']}");

                if (doctorData['specialization'] == _userCondition) {
                  print("Doctor $doctorId matches the user's condition.");

                  DatabaseReference questionnairesRef = _dbRef.child(
                      'administrator/doctors/$doctorId/activeQuestionnaires');
                  DatabaseEvent questionnairesEvent =
                      await questionnairesRef.once();

                  if (questionnairesEvent.snapshot.exists) {
                    var questionnairesData = questionnairesEvent.snapshot.value;
                    print("Questionnaire data found for doctor $doctorId.");

                    if (questionnairesData is Map) {
                      Map<String, dynamic> categoriesMap =
                          Map<String, dynamic>.from(questionnairesData);

                      setState(() {
                        _questions = categoriesMap.entries
                            .where((categoryEntry) => categoryEntry.value
                                is Map) // Skip invalid entries
                            .map((categoryEntry) {
                              var categoryData = categoryEntry.value;
                              if (categoryData is Map) {
                                return categoryData.entries
                                    .map((questionEntry) {
                                      var questionData = questionEntry.value;
                                      if (questionData is Map) {
                                        String questionText =
                                            questionData['question'] ??
                                                'Unknown question';

                                        List<Map<String, dynamic>> choices = [];
                                        var legendData = questionData['legend'];
                                        var valueData = questionData['value'];

                                        if (legendData is List &&
                                            valueData is List) {
                                          for (int i = 0;
                                              i < legendData.length;
                                              i++) {
                                            var choiceText =
                                                legendData[i]?.toString();
                                            var choiceValue = double.tryParse(
                                                    valueData[i]?.toString() ??
                                                        '0.0') ??
                                                0.0;

                                            if (choiceText != null &&
                                                choiceText.isNotEmpty) {
                                              choices.add({
                                                'text': choiceText,
                                                'value': choiceValue,
                                              });
                                            }
                                          }
                                        }

                                        print(
                                            "Question fetched: $questionText with choices: $choices");
                                        return Questions(
                                          questions: questionText,
                                          choices: choices,
                                        );
                                      }
                                      return null;
                                    })
                                    .where((q) => q != null)
                                    .cast<Questions>()
                                    .toList();
                              }
                              return null;
                            })
                            .expand((questionsList) => questionsList ?? [])
                            .cast<Questions>()
                            .toList();
                      });
                    }
                    break;
                  } else {
                    print("No questionnaire data found for doctor $doctorId.");
                  }
                }
              }
            } else {
              print("No doctors data found.");
            }
          } else {
            print("Failed to fetch doctors.");
          }
        } else {
          print("User condition data is empty or not a list.");
        }
      } else {
        print("Failed to fetch user condition data.");
      }
    } else {
      print("No user logged in.");
    }
  }

  void _saveAnswer(
      String condition, String question, String legend, double value) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String userUID = user.uid;
      String answerID = 'Q${_currentQuestionIndex + 1}';

      DatabaseReference answersRef = _dbRef.child(
          'administrator/users/$userUID/all_answers/$condition/$_answerSetKey/$answerID');

      await answersRef.set({
        'question': question,
        'legend': legend,
        'value': value,
      });
    }
  }

  void _saveFinalData() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null && _userCondition != null) {
      String userUID = user.uid;
      DatabaseReference answerSetRef = _dbRef.child(
          'administrator/users/$userUID/all_answers/$_userCondition/$_answerSetKey');

      await answerSetRef.update({
        'timestamp': _getFormattedTimestamp(),
        'total_value': _totalValue,
      });
    }
  }

  void _endQuestion() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Well done!"),
          content: const Text(
            "Thank you for answering the weekly questionnaire. This will help greatly in monitoring your progress.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => HomePage()),
                );
                setState(() {
                  _currentQuestionIndex = 0;
                  _totalValue = 0.0;
                  _initializeAnswerSet();
                });
              },
              child: const Text("Exit"),
            )
          ],
        );
      },
    );
  }

  void _nextQuestion() {
    if (_selectedAnswers[_currentQuestionIndex] != null &&
        _userCondition != null) {
      final currentQuestion = _questions[_currentQuestionIndex];

      double chosenValue = 0.0;
      String legend = '';
      for (var choice in currentQuestion.choices) {
        if (choice['text'] == _selectedAnswers[_currentQuestionIndex]) {
          chosenValue = choice['value'];
          legend = choice['text'];
          break;
        }
      }

      _totalValue += chosenValue;
      _saveAnswer(
          _userCondition!, currentQuestion.questions, legend, chosenValue);

      setState(() {
        if (_currentQuestionIndex < _questions.length - 1) {
          _currentQuestionIndex++;
        } else {
          _saveFinalData();
          _endQuestion(); // Now this is safe because _endQuestion is already defined
        }
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _selectedAnswers[_currentQuestionIndex] ??= null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion =
        _questions.isNotEmpty ? _questions[_currentQuestionIndex] : null;
    double progressBar = _questions.isNotEmpty
        ? (_currentQuestionIndex + 1) / _questions.length
        : 0;

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
                      onPressed:
                          _currentQuestionIndex == 0 ? null : _previousQuestion,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _currentQuestionIndex == 0
                            ? Colors.grey
                            : AppColors.lightGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40, right: 40),
                        child: Text(
                          "Weekly Profile",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 15,
              width: double.infinity,
              child: Stack(
                children: [
                  LinearProgressIndicator(
                    value: progressBar,
                    backgroundColor: AppColors.dirtyWhite,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.progressBarColor),
                    minHeight: 15,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      _questions.length,
                      (index) => SizedBox(
                        height: 15,
                        width: 11,
                        child: Image.asset(
                          'assets/diamond.png',
                          color: (index <= _currentQuestionIndex)
                              ? Colors.blue
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (currentQuestion != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  currentQuestion.questions,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (currentQuestion != null)
              ...currentQuestion.choices.map((choice) {
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
                      groupValue: _selectedAnswers[_currentQuestionIndex],
                      onChanged: (String? value) {
                        setState(() {
                          _selectedAnswers[_currentQuestionIndex] = value;
                        });
                        Future.delayed(
                          const Duration(milliseconds: 500),
                          _nextQuestion,
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
