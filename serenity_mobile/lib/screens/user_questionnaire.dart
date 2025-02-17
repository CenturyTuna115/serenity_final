import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/models/questions.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:intl/intl.dart';
import 'package:serenity_mobile/screens/doctor_dashboard.dart';

class UserQuestionnaire extends StatefulWidget {
  const UserQuestionnaire({super.key});

  @override
  _UserQuestionnaireState createState() => _UserQuestionnaireState();
}

class _UserQuestionnaireState extends State<UserQuestionnaire> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Questions> _questions = [];
  int _currentQuestionIndex = 0;
  Map<int, String?> _selectedAnswers = {};
  double _totalValue = 0.0;
  String _answerSetKey = '';
  String? _userCondition;

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
    final String formatted =
        formatter.format(now.toUtc().add(const Duration(hours: 8)));
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

          fetchQuestionsBasedOnCondition();
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
    if (_userCondition != null) {
      DatabaseReference baseRef = _dbRef.child(
          'administrator/defaultQuestionnaires/$_userCondition/$_userCondition');

      DatabaseEvent baseEvent = await baseRef.once();
      if (baseEvent.snapshot.exists && baseEvent.snapshot.value is Map) {
        var categories = baseEvent.snapshot.value as Map<dynamic, dynamic>;

        List<Questions> fetchedQuestions = [];
        for (var categoryKey in categories.keys) {
          var subCategory = categories[categoryKey];
          if (subCategory is Map<dynamic, dynamic>) {
            for (var questionKey in subCategory.keys) {
              var questionData = subCategory[questionKey];
              if (questionData is Map<dynamic, dynamic> &&
                  questionData.containsKey('question') &&
                  questionData.containsKey('legend') &&
                  questionData.containsKey('value')) {
                String questionText = questionData['question'];
                List<dynamic> legends = questionData['legend'] as List<dynamic>;
                List<dynamic> values = questionData['value'] as List<dynamic>;

                if (legends.length == values.length) {
                  // Ensure both lists are the same length
                  List<Map<String, dynamic>> choices = [];
                  for (int i = 0; i < legends.length; i++) {
                    String choiceText = legends[i].toString();
                    double score = double.tryParse(values[i].toString()) ?? 0.0;
                    choices.add({
                      'text': choiceText,
                      'value': score,
                    });
                  }

                  fetchedQuestions
                      .add(Questions(question: questionText, choices: choices));
                }
              }
            }
          }
        }

        setState(() {
          _questions = fetchedQuestions;
        });
      } else {
        print(
            "No questions found for condition: $_userCondition at path: ${baseRef.path}");
      }
    }
  }

  void _saveAnswer(String question, String legend, double value) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null && _userCondition != null) {
      String userUID = user.uid;
      String answerID = 'Q${_currentQuestionIndex + 1}';

      DatabaseReference answersRef = _dbRef.child(
          'administrator/users/$userUID/all_answers/$_userCondition/$_answerSetKey/$answerID');

      await answersRef.set({
        'question': question,
        'legend': legend,
        'value': value,
      });

      print(
          "Answer saved for question $question with legend $legend and value $value.");
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

      DatabaseReference userRef = _dbRef.child('administrator/users/$userUID');
      await userRef.update({
        'questionnaire_completed': true,
      });

      print("Final data saved, and questionnaire marked as completed.");
    }
  }

  void _nextQuestion() {
    if (_selectedAnswers[_currentQuestionIndex] != null) {
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

      _saveAnswer(currentQuestion.question, legend, chosenValue);

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

  void _endQuestion() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Well done!"),
          content: const Text(
            "Thank you for answering the initial questionnaire. This questionnaire will help greatly in diagnosing your condition and hopefully cure it. Have a great day!",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => DoctorDashboard()),
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
                          "Initial Questions",
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
            Stack(
              alignment: Alignment.center,
              children: [
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_questions.length, (index) {
                    return Image.asset(
                      'assets/diamond.png',
                      height: 15,
                      width: 15,
                      color: index <= _currentQuestionIndex
                          ? Colors.blue
                          : Colors.grey, // Color based on progress
                    );
                  }),
                ),
              ],
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
