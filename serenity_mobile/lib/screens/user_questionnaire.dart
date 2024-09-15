import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/models/questions.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:intl/intl.dart';
import 'package:serenity_mobile/screens/doctor_dashboard.dart';
import 'homepage.dart';

class UserQuestionnaire extends StatefulWidget {
  const UserQuestionnaire({super.key});

  @override
  _UserQuestionnaireState createState() => _UserQuestionnaireState();
}

class _UserQuestionnaireState extends State<UserQuestionnaire> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Questions> _questions = [];
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  double _totalValue = 0.0;
  String _answerSetKey = '';

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

      // Generate a new key for the current answer set
      DatabaseReference userAnswersRef =
          _dbRef.child('administrator/users/$userUID/all_answers').push();
      _answerSetKey = userAnswersRef.key!; // Save the generated key
      print("Generated answer set key: $_answerSetKey");
    }
  }

  String _getFormattedTimestamp() {
    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formatted = formatter.format(now
        .toUtc()
        .add(const Duration(hours: 8))); // Convert to Philippine Time (UTC+8)
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
          String userCondition =
              userConditionData[0]; // Get the first condition
          print("User condition: $userCondition");

          // Fetch doctors based on the first condition of the user
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

                if (doctorData['specialization'] == userCondition) {
                  print("Doctor $doctorId matches the user's condition.");

                  // Fetch questions for the doctor that matches the user's first condition
                  DatabaseReference questionnairesRef = _dbRef.child(
                      'administrator/doctors/$doctorId/activeQuestionnaires');
                  DatabaseEvent questionnairesEvent =
                      await questionnairesRef.once();

                  if (questionnairesEvent.snapshot.exists) {
                    var questionnairesData = questionnairesEvent.snapshot.value;
                    print("Questionnaire data found for doctor $doctorId.");

                    if (questionnairesData is Map) {
                      setState(() {
                        _questions = questionnairesData.entries.map((entry) {
                          Map<String, dynamic> questionData =
                              Map<String, dynamic>.from(entry.value as Map);

                          // Extract question
                          String questionText = questionData['question'];

                          // Extract legend choices and corresponding values
                          List<Map<String, dynamic>> choices = [];
                          if (questionData.containsKey('legend') &&
                              questionData.containsKey('value')) {
                            var legendData = questionData['legend'];
                            var valueData = questionData['value'];

                            if (legendData is List && valueData is List) {
                              for (int i = 0; i < legendData.length; i++) {
                                choices.add({
                                  'text': legendData[i],
                                  'value': double.tryParse(valueData[i]) ?? 0.0,
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
                        }).toList();
                      });
                    }
                    break; // Stop after finding the first matching doctor
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

  void _saveAnswer(String question, String legend, double value) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String userUID = user.uid;

      // Create answerID as Q1, Q2, Q3, etc.
      String answerID = 'Q${_currentQuestionIndex + 1}';

      // Reference to the specific answer set
      DatabaseReference answersRef = _dbRef.child(
          'administrator/users/$userUID/all_answers/$_answerSetKey/$answerID');

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

    if (user != null) {
      String userUID = user.uid;

      // Reference to the specific answer set
      DatabaseReference answerSetRef = _dbRef
          .child('administrator/users/$userUID/all_answers/$_answerSetKey');

      // Store the timestamp and total value after all questions are answered
      await answerSetRef.update({
        'timestamp': _getFormattedTimestamp(),
        'total_value': _totalValue,
      });

      // Update the user's questionnaire_completed field to true
      DatabaseReference userRef = _dbRef.child('administrator/users/$userUID');
      await userRef.update({
        'questionnaire_completed': true,
      });

      print("Final data saved, and questionnaire marked as completed.");
    }
  }

  void _nextQuestion() {
    if (_selectedAnswer != null) {
      final currentQuestion = _questions[_currentQuestionIndex];

      // Find the chosen value based on the selected answer
      double chosenValue = 0.0;
      String legend = '';
      for (var choice in currentQuestion.choices) {
        if (choice['text'] == _selectedAnswer) {
          chosenValue = choice['value'];
          legend = choice['text'];
          break;
        }
      }

      // Add the chosen value to the total value
      _totalValue += chosenValue;

      // Save the answer to the database
      _saveAnswer(currentQuestion.questions, legend, chosenValue);

      // Move to the next question or end the questionnaire
      setState(() {
        _selectedAnswer = null;
        if (_currentQuestionIndex < _questions.length - 1) {
          _currentQuestionIndex++;
        } else {
          _saveFinalData(); // Save timestamp and total value after all questions are answered
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
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomePage()),
      );
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
                  // Reset the total value
                  _totalValue = 0.0;
                  // Initialize a new answer set for future answers
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
                      onPressed: _previousQuestion,
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
            SizedBox(
              height: 15,
              child: Stack(
                children: [
                  Positioned(
                    child: LinearProgressIndicator(
                      value: progressBar,
                      backgroundColor: AppColors.dirtyWhite,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.progressBarColor,
                      ),
                      minHeight: 15,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  for (int i = 0; i < _questions.length; i++)
                    Positioned(
                      left: i * 50.0,
                      child: SizedBox(
                        height: 15,
                        width: 11,
                        child: Image.asset('assets/diamond.png'),
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
                    child: CheckboxListTile(
                      tileColor: AppColors.dirtyWhite,
                      title: Text(choice['text']),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 30,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      value: _selectedAnswer == choice['text'],
                      onChanged: (bool? value) {
                        if (value == true) {
                          setState(() {
                            _selectedAnswer = choice['text'];
                          });
                          Future.delayed(
                            const Duration(milliseconds: 500),
                            _nextQuestion,
                          );
                        }
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
