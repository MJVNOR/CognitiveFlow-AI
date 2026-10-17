import 'parsing.dart';

List<Attempt> parseAttempts(List<dynamic> raw) =>
    parseModelList(raw, Attempt.fromJson);

class Attempt {
  final String id;
  final String answer;
  final Map<String, dynamic> input;
  const Attempt({required this.id, this.answer = '', this.input = const {}});
  factory Attempt.fromJson(Map<String, dynamic> json) => Attempt(
        id: json['id'] as String,
        answer: json['answer'] as String? ?? '',
        input: json['input'] as Map<String, dynamic>? ?? {},
      );
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'answer': answer,
        'input': input,
      };
}
