class DelfTestSummary {
  DelfTestSummary({
    required this.id,
    required this.title,
    required this.level,
    required this.description,
    required this.questionCount,
    required this.passingScore,
  });

  final int id;
  final String title;
  final String level;
  final String description;
  final int questionCount;
  final int passingScore;

  factory DelfTestSummary.fromJson(Map<String, dynamic> json) {
    return DelfTestSummary(
      id: json['id'] as int,
      title: json['title'] as String,
      level: json['level'] as String,
      description: json['description'] as String? ?? '',
      questionCount: json['question_count'] as int? ?? 0,
      passingScore: json['passing_score'] as int? ?? 70,
    );
  }
}

class DelfQuestion {
  DelfQuestion({
    required this.id,
    required this.prompt,
    required this.choices,
  });

  final String id;
  final String prompt;
  final List<String> choices;

  factory DelfQuestion.fromJson(Map<String, dynamic> json) {
    return DelfQuestion(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      choices: (json['choices'] as List<dynamic>? ?? const <dynamic>[]).map((e) => e.toString()).toList(),
    );
  }
}

class DelfTestDetail {
  DelfTestDetail({
    required this.id,
    required this.title,
    required this.level,
    required this.description,
    required this.questions,
    required this.passingScore,
  });

  final int id;
  final String title;
  final String level;
  final String description;
  final List<DelfQuestion> questions;
  final int passingScore;

  factory DelfTestDetail.fromJson(Map<String, dynamic> json) {
    return DelfTestDetail(
      id: json['id'] as int,
      title: json['title'] as String,
      level: json['level'] as String,
      description: json['description'] as String? ?? '',
      questions: (json['questions'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(DelfQuestion.fromJson)
          .toList(),
      passingScore: json['passing_score'] as int? ?? 70,
    );
  }
}

class DelfSubmitResult {
  DelfSubmitResult({
    required this.resultId,
    required this.score,
    required this.correctCount,
    required this.totalQuestions,
    required this.passed,
  });

  final int resultId;
  final int score;
  final int correctCount;
  final int totalQuestions;
  final bool passed;

  factory DelfSubmitResult.fromJson(Map<String, dynamic> json) {
    return DelfSubmitResult(
      resultId: json['result_id'] as int,
      score: json['score'] as int,
      correctCount: json['correct_count'] as int,
      totalQuestions: json['total_questions'] as int,
      passed: json['passed'] as bool? ?? false,
    );
  }
}
