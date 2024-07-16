import 'package:flutter/material.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:serenity_mobile/models/questions.dart';
import 'homepage.dart';  // Import the HomePage

class Questionnaires extends StatefulWidget {
  const Questionnaires({super.key});

  @override
  _QuestionnairesState createState() => _QuestionnairesState();
}

class _QuestionnairesState extends State<Questionnaires> {
  final List<Questions> _questions = [
    Questions(
      questions:
          "Thinking about a typical night this week. How long does it take you to fall asleep?",
      answers: [
        "0-15 minutes",
        "16-30 minutes",
        "31-45 minutes",
        "46-60 minutes",
        "61 minutes",
      ],
    ),
    Questions(
      questions:
          "Thinking about a typical night this week. If you then wake up during the night, how long are you awake for in total?",
      answers: [
        "0-15 minutes",
        "16-30 minutes",
        "31-45 minutes",
        "46-60 minutes",
        "more than 60 minutes",
      ],
    ),
    Questions(
      questions:
          "How many nights a week do you have a problem with your sleep?",
      answers: [
        "1 night",
        "2 nights",
        "3 nights",
        "4 nights",
        "5-7 nights",
      ],
    ),
    Questions(
      questions: "How would you rate your sleep quality?",
      answers: [
        "Very Good",
        "Good",
        "Average",
        "Poor",
        "Very Poor",
      ],
    ),
    Questions(
      questions:
          "Thinking about this week, to what extent has poor sleep affected your mood, energy, or relationships?",
      answers: [
        "Not at all",
        "A little",
        "Somewhat",
        "Much",
        "Very Much",
      ],
    ),
    Questions(
      questions:
          "Thinking about this week, to what extent has poor sleep affected your concentration, productivity, or ability to stay awake?",
      answers: [
        "Not at all",
        "A little",
        "Somewhat",
        "Much",
        "Very Much",
      ],
    ),
    Questions(
      questions:
          "Thinking about this week, to what extent has poor sleep troubled you in general?",
      answers: [
        "Not at all",
        "A little",
        "Somewhat",
        "Much",
        "Very Much",
      ],
    ),
    Questions(
        questions: "How long have you had a problem with your sleep?",
        answers: [
          "1 month",
          "1-2 months",
          "3-6 months",
          "7-12 months",
          "more than 1 year",
        ])
  ];

  int _currentQuestionIndex = 0;
  String? _selectedAnswer;

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
    setState(() {
      if (_currentQuestionIndex > 0) {
        _currentQuestionIndex--;
      }
    });
  }

  void _endQuestion() {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              "Well done!",
            ),
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
        });
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = _questions[_currentQuestionIndex];
    double progressBar = (_currentQuestionIndex + 1) / _questions.length;

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
                              borderRadius: BorderRadius.circular(0)),
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
                        ))
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
                            AppColors.progressBarColor),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  currentQuestion.questions,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              ...currentQuestion.answers.map((answer) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9, // Adjust width according to screen size
                    child: CheckboxListTile(
                      tileColor: AppColors.dirtyWhite,
                      title: Text(answer),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 30),
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
                              const Duration(milliseconds: 500), _nextQuestion);
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 20), // Add some padding at the bottom
            ],
          ),
        ));
  }
}
