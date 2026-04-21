class ProgressItemModel {
  const ProgressItemModel({
    required this.lessonId,
    required this.completed,
    required this.score,
  });

  final int lessonId;
  final bool completed;
  final int score;

  factory ProgressItemModel.fromJson(Map<String, dynamic> json) {
    return ProgressItemModel(
      lessonId: json['lesson_id'] as int,
      completed: json['completed'] as bool,
      score: json['score'] as int,
    );
  }
}
