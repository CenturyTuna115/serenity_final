class Questions {
  final String question; // Ensure this is 'question' not 'questions'
  final List<Map<String, dynamic>> choices;

  Questions({
    required this.question,
    required this.choices,
  });

  factory Questions.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> parsedChoices = [];
    if (map.containsKey('legend') && map.containsKey('value')) {
      Map<String, dynamic> legends = map['legend'];
      Map<String, dynamic> values = map['value'];

      legends.forEach((key, value) {
        double parsedValue = double.tryParse(values[key].toString()) ?? 0.0;
        parsedChoices.add({'text': value, 'value': parsedValue});
      });
    }
    return Questions(
      question: map['question'], // Ensure this matches the JSON key
      choices: parsedChoices,
    );
  }
}
