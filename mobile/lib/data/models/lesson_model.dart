class LessonModel {
  LessonModel({
    required this.id,
    required this.level,
    required this.type,
    required this.content,
    required this.xpReward,
    required this.orderIndex,
    required this.completed,
    required this.unlocked,
  });

  final int id;
  final String level;
  final String type;
  final Map<String, dynamic> content;
  final int xpReward;
  final int orderIndex;
  final bool completed;
  final bool unlocked;

  LessonModel copyWith({
    int? id,
    String? level,
    String? type,
    Map<String, dynamic>? content,
    int? xpReward,
    int? orderIndex,
    bool? completed,
    bool? unlocked,
  }) {
    return LessonModel(
      id: id ?? this.id,
      level: level ?? this.level,
      type: type ?? this.type,
      content: content ?? this.content,
      xpReward: xpReward ?? this.xpReward,
      orderIndex: orderIndex ?? this.orderIndex,
      completed: completed ?? this.completed,
      unlocked: unlocked ?? this.unlocked,
    );
  }

  factory LessonModel.fromJson(Map<String, dynamic> json) => LessonModel(
        id: json['id'] as int,
        level: json['level'] as String,
        type: json['type'] as String,
        content: json['content'] as Map<String, dynamic>,
        xpReward: json['xp_reward'] as int,
        orderIndex: json['order_index'] as int,
        completed: json['completed'] as bool? ?? false,
        unlocked: json['unlocked'] as bool? ?? false,
      );
}
