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
  String? _userCondition;
  String? _doctorId;

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
      DatabaseReference userAnswersRef =
          _dbRef.child('administrator/users/$userUID/all_answers').push();
      _answerSetKey = userAnswersRef.key!;
      print("Generated answer set key: $_answerSetKey");
    }
  }

  String _getFormattedTimestamp() {
    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return formatter.format(now.toUtc().add(const Duration(hours: 8)));
  }

  void _fetchUserConditionAndQuestions() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String userUID = user.uid;

      // Fetch user condition
      DatabaseReference userRef =
          _dbRef.child('administrator/users/$userUID/conditions');
      DatabaseEvent userEvent = await userRef.once();

      if (userEvent.snapshot.exists) {
        var userConditionData = userEvent.snapshot.value;
        if (userConditionData is List && userConditionData.isNotEmpty) {
          _userCondition = userConditionData[0];
          print("User condition: $_userCondition");

          // Fetch assigned doctor from mydoctors node
          DatabaseReference myDoctorsRef =
              _dbRef.child('administrator/users/$userUID/mydoctors');
          DatabaseEvent doctorEvent = await myDoctorsRef.once();

          if (doctorEvent.snapshot.exists) {
            var doctorData =
                doctorEvent.snapshot.value as Map<dynamic, dynamic>;
            if (doctorData.isNotEmpty) {
              var firstDoctor = doctorData.values.first;
              _doctorId = firstDoctor['doctorId'];
              print("Assigned Doctor ID: $_doctorId");

              if (_doctorId != null && _userCondition != null) {
                fetchQuestionsBasedOnCondition();
              }
            } else {
              print("No assigned doctor found in mydoctors.");
            }
          } else {
            print("mydoctors node does not exist for the user.");
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

  void fetchQuestionsBasedOnCondition() async {
    if (_userCondition != null && _doctorId != null) {
      DatabaseReference baseRef = _dbRef.child(
          'administrator/doctors/$_doctorId/activeQuestionnaires/$_userCondition/$_userCondition');

      DatabaseEvent baseEvent = await baseRef.once();
      if (baseEvent.snapshot.exists && baseEvent.snapshot.value is Map) {
        var categories = baseEvent.snapshot.value as Map<dynamic, dynamic>;

        List<Questions> fetchedQuestions = [];
        for (var categoryKey in categories.keys) {
          var subCategory = categories[categoryKey];
          if (subCategory is Map<dynamic, dynamic>) {
            for (var questionKey in subCategory.keys) {
              var questionData = subCategory[questionKey];
              if (questionData is Map<dynamic, dynamic>) {
                // Validate required fields
                if (questionData.containsKey('question') &&
                    questionData.containsKey('legend') &&
                    questionData.containsKey('value')) {
                  String questionText = questionData['question'];
                  List<dynamic> legends =
                      questionData['legend'] as List<dynamic>;
                  List<dynamic> values = questionData['value'] as List<dynamic>;

                  if (legends.length == values.length) {
                    List<Map<String, dynamic>> choices = [];
                    for (int i = 0; i < legends.length; i++) {
                      String choiceText = legends[i].toString();
                      double score =
                          double.tryParse(values[i].toString()) ?? 0.0;
                      choices.add({
                        'text': choiceText,
                        'value': score,
                      });
                    }
                    fetchedQuestions.add(
                        Questions(question: questionText, choices: choices));
                  } else {
                    print(
                        "Invalid data format for question: $questionKey. Legend and value lengths do not match.");
                  }
                } else {
                  print(
                      "Invalid question data format for key: $questionKey. Missing required fields.");
                }
              } else {
                print("Invalid question data type for key: $questionKey.");
              }
            }
          }
        }

        setState(() {
          _questions = fetchedQuestions;
        });

        print("Processed fetched questions: $_questions");
      } else {
        print(
            "No questions found for condition: $_userCondition at path: ${baseRef.path}");
      }
    } else {
      print("User condition or doctor ID is null.");
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

      // Save the answers and timestamp
      DatabaseReference answerSetRef = _dbRef.child(
          'administrator/users/$userUID/all_answers/$_userCondition/$_answerSetKey');

      await answerSetRef.update({
        'timestamp': _getFormattedTimestamp(),
        'total_value': _totalValue,
      });

      // Save the last answered timestamp
      DatabaseReference userRef =
          _dbRef.child('administrator/users/$userUID/last_answered');

      await userRef.set({
        'condition': _userCondition,
        'timestamp': _getFormattedTimestamp(),
      });

      print("Last answered timestamp saved.");
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
          _userCondition!, currentQuestion.question, legend, chosenValue);

      setState(() {
        if (_currentQuestionIndex < _questions.length - 1) {
          _currentQuestionIndex++;
        } else {
          _saveFinalData();
          _endQuestion();
        }
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
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
                          _currentQuestionIndex > 0 ? _previousQuestion : null,
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
                    child: Center(
                      child: const Padding(
                        padding: EdgeInsets.only(top: 40, right: 40),
                        child: Text(
                          "Weekly Questions",
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
              child: LinearProgressIndicator(
                value: progressBar,
                backgroundColor: AppColors.dirtyWhite,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.progressBarColor),
                minHeight: 15,
              ),
            ),
            const SizedBox(height: 20),
            if (currentQuestion != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  currentQuestion.question,
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
