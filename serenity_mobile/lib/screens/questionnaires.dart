import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:serenity_mobile/models/questions.dart';
import 'homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serenity App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const Questionnaires(),
    );
  }
}

class Questionnaires extends StatefulWidget {
  const Questionnaires({super.key});

  @override
  _QuestionnairesState createState() => _QuestionnairesState();
}

class _QuestionnairesState extends State<Questionnaires> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Questions> _questions = [];
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _fetchUserConditionAndQuestions();
  }

  void _fetchUserConditionAndQuestions() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String userUID = user.uid;
      DatabaseReference userRef =
          _dbRef.child('administrator/users/$userUID/condition');
      DatabaseEvent userEvent = await userRef.once();

      if (userEvent.snapshot.exists) {
        String userCondition = userEvent.snapshot.value.toString();

        // Fetch doctors based on user's condition
        DatabaseEvent doctorsEvent =
            await _dbRef.child('administrator/doctors').once();

        if (doctorsEvent.snapshot.exists) {
          Map<String, dynamic> doctors =
              Map<String, dynamic>.from(doctorsEvent.snapshot.value as Map);
          for (var doctorId in doctors.keys) {
            var doctorData = doctors[doctorId];
            if (doctorData['specialization'] == userCondition) {
              DatabaseReference questionnairesRef = _dbRef
                  .child('administrator/doctors/$doctorId/questionnaires');
              DatabaseEvent questionnairesEvent =
                  await questionnairesRef.once();

              if (questionnairesEvent.snapshot.exists) {
                Map<String, dynamic> questionnaires = Map<String, dynamic>.from(
                    questionnairesEvent.snapshot.value as Map);
                setState(() {
                  _questions = questionnaires.entries.map((entry) {
                    return Questions(
                      questions: entry.value,
                      answers: [], // Replace with actual answers if available
                    );
                  }).toList();
                });
                break; // Stop after finding the first matching doctor
              }
            }
          }
        }
      }
    }
  }

  void _nextQuestion() {
    setState(() {
      _selectedAnswer = null;
      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        _endQuestion();
      }
    });
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
            "Thank you for answering the weekly questionnaire. This questionnaire will help greatly in diagnosing your condition and hopefully cure it. Have a great day!",
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
                      child: Image.asset('assets/arrow_bac.png'),
                    ),
                  ),
                  const SizedBox(width: 60),
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: Image.asset('assets/logo.png'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Image.asset('assets/SERENITY.png'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Center(
              child: Text(
                "WEEKLY PROFILE",
                style: TextStyle(
                  color: AppColors.blueGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 30),
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
                        width: 15,
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
              ...currentQuestion.answers.map((answer) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: CheckboxListTile(
                      tileColor: AppColors.dirtyWhite,
                      title: Text(answer),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 30,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      value: _selectedAnswer == answer,
                      onChanged: (bool? value) {
                        if (value == true) {
                          setState(() {
                            _selectedAnswer = answer;
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
